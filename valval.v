
module valval

import net
import net.urllib
import json
import os
import time
import strings


const (
	version = '0.1.4'
	v_version = '0.1.24'
	http_404 = 'HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\n\r\n404 Not Found'
	http_413 = 'HTTP/1.1 413 Request Entity Too Large\r\nContent-Type: text/plain\r\n\r\n413 Request Entity Too Large'
	http_500 = 'HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\n\r\n500 Internal Server Error'
	post_body_limit = 1024 * 1024 * 20  // 20MB
	api_key_flag = 'valvalapikey'  		// the param name won't be used anywhere else
)

// ===== structs ======

pub struct Request {
	pub:
		app App
		method string
		path string
		query map[string]string
		form map[string]string
		body string
		headers map[string]string
}

pub fn (req Request) get(key string, default_value string) string {
	if key in req.form {
		return req.form[key]
	}
	if key in req.query {
		return req.query[key]
	}
	return default_value
}

pub fn (req Request) is_api() bool {
	// api request by axios
	return api_key_flag in req.query
}

pub fn (req Request) is_page() bool {
	// the first page view
	return !req.is_api()
}


pub struct Response {
	mut pub:
		status int = 200
		body string = ''
		content_type string = 'text/html; charset=utf-8'
		headers map[string]string
}

pub fn (mut res Response) set_header(key string, value string) {
	res.headers[key] = value
}

fn (res Response) header_text() string {
	// res.header_text() => '// Content-Encoding: UTF-8\r\nContent-Length: 138\r\n'
	mut text := ''
	keys := res.headers.keys()
	for key in keys {
		value := res.headers[key]
		text += '$key: $value\r\n'
	}
	return text
}

fn (res Response) status_msg() string {
	// res.status_msg() => 'OK'
	msg := match res.status {
		100 { 'Continue' }
		101 { 'Switching Protocols' }
		200 { 'OK' }
		201 { 'Created' }
		202 { 'Accepted' }
		203 { 'Non-Authoritive Information' }
		204 { 'No Content' }
		205 { 'Reset Content' }
		206 { 'Partial Content' }
		300 { 'Multiple Choices' }
		301 { 'Moved Permanently' }
		400 { 'Bad Request' }
		401 { 'Unauthorized' }
		403 { 'Forbidden' }
		404 { 'Not Found' }
		405 { 'Method Not Allowed' }
		408 { 'Request Timeout' }
		500 { 'Internal Server Error' }
		501 { 'Not Implemented' }
		502 { 'Bad Gateway' }
		else { '-' }
	}
	return msg
}


pub struct View {
		req Request
		template string
		ui string = 'element'
	mut:
		context map[string]string
	pub:
		content string  // html after template compiled
		error string  // because of https://github.com/vlang/v/issues/1709, new_view function could return option, so put it here.
}

pub fn (mut view View) set(key string, data string) {
	// data should be a json str of obj / str / int / bool / list ..
	view.context[key.trim_space()] = data
}

fn (view View) get(key string) string {
	if key in view.context {
		return view.context[key]
	}
	return '{}'
}


pub struct App {
	pub:
		name string = 'ValvalApp'
		debug bool = true
		run_ts int = 0
	mut:
		router map[string]Handler
		static_map map[string]string
}

pub fn (mut app App) route(path string, func fn(Request) Response) {
	// route path should not be ends with /
	rpath := path.trim_right('/')
	app.router[rpath] = Handler{func}
}

pub fn (mut app App) register(path string, func fn(Request) Response) {
	// as same as route
	app.route(path, func)
}

pub fn (mut app App) serve_static(static_prefix string, static_root string) {
	// app.serve_static('/static/', './static/')
	mut prefix := static_prefix
	mut root := static_root
	if !prefix.ends_with('/') {
		prefix += '/'
	}
	if !root.ends_with('/') {
		root += '/'
	}
	app.static_map[prefix] = root
}

fn (app App) handle(method string, path string, query_str string, body string, headers map[string]string) Response {

	for static_prefix in app.static_map.keys() {
		if path.starts_with(static_prefix) {
			static_root := app.static_map[static_prefix]
			fpath := path.replace_once(static_prefix, static_root)
			return response_file(fpath)
		}
	}
	query := urldecode(query_str)
	mut form := map[string]string
	if headers['content-type'] in ['application/x-www-form-urlencoded', ''] {
		form = urldecode(body)
	}
	req := Request{
		app: app
		method: method
		path: path
		query: query
		form: form
		body: body
		headers: headers
	}
	handler := app.find_handler(req)
	func := handler.func
	res := func(req)
	return res
}

fn (app App) find_handler(req Request) Handler {
	router := app.router
	path := req.path.trim_right('/')
	method_path := '${req.method}:$path'
	// first match `method:path`
	if (method_path in router) {
		return router[method_path]
	}
	// then math path
	if (path in router) {
		return router[path]
	}
	// then use common handler if it exists
	if '*' in router {
		return router['*']
	}
	// last return default handler
	return Handler{default_handler_func}
}


struct Server {
	pub:
		address string = '0.0.0.0'
		port int = 8012
	mut:
		app App
}

pub fn (server Server) run() {
	app := server.app
    println('${app.name} running on http://$server.address:$server.port ...')
	println('Working in: ${os.getwd()}')
	println('Server OS: ${os.user_os()}, Debug: ${app.debug}')
	println('Valval version: $version, support V version: $v_version')

    // listener := net.listen(server.port) or { panic('failed to listen') }
    for {
		listener := net.listen(server.port) or { panic('failed to listen') }
		conn := listener.accept() or { panic('accept failed') }
		listener.close() or {} // todo: do not close listener and recreate it everytime
		if app.debug {
			println('===============')
			println(conn)
		}
		message := readall(conn, app.debug) or {
			println(err)
			if err == '413' {
				conn.write(http_413) or {}
			} else {
				conn.write(http_500) or {}
			}
			conn.close() or {}
			continue
		}
		if app.debug {
			println('------------')
			println(message)
		}
		lines := message.split_into_lines()
		if lines.len < 2 {
			println('invalid message for http')
			conn.write(http_500) or {}
			conn.close() or {}
			continue
		}
		first_line := lines[0].trim_space()
		items := first_line.split(' ')
		if items.len < 2 {
			println('invalid data for http')
			conn.write(http_500) or {}
			conn.close() or {}
			continue
		}
		method := items[0].to_upper()
		// url => <scheme>://<netloc>/<path>;<params>?<query>#<fragment>
		url := items[1]
		path := url.all_before('?')
		mut query := ''
		if url.contains('?') {
			query = url.all_after('?').all_before('#')
		}
		println(first_line)
		if app.debug {
			println('------------')
			println(items)
			println('$method, $url, $path, $query')
		}
		mut headers := map[string]string
		mut body := ''
		mut flag := true
		// length of lines must more than 2
		for line in lines[1..] {
			sline := line.trim_space()
			if sline == '' {
				flag = false
			}
			if flag {
				header_name, header_value := split2(sline, ':')
				headers[header_name.to_lower()] = header_value.trim_space()
			} else {
				body += sline + '\r\n'
			}
		}
		body = body.trim_space()
		if app.debug {
			println('------ request headers ------')
			println(headers)
			if body.len > 2000 {
				println(body[..2000] + ' ...')
			} else {
				println(body)
			}
		}

		res := app.handle(method, path, query, body, headers)

		mut builder := strings.new_builder(1024)
		builder.write('HTTP/1.1 $res.status ${res.status_msg()}\r\n')
		builder.write('Content-Type: $res.content_type\r\n')
		builder.write('Content-Length: $res.body.len\r\n')
		builder.write('Connection: close\r\n')
		builder.write('${res.header_text()}')
		builder.write('\r\n')

		result := builder.str()
		conn.send_string(result) or {}
		if app.debug {
			println('------ response headers ------')
			if result.len > 500 {
				println(result[..500] + ' ...')
			} else {
				println(result)
			}
		}
		builder.free()

		conn.send_string(res.body) or {}
		if app.debug {
			println('------- response body -----')
			if res.body.len > 2000 {
				println(res.body[..2000] + ' ...')
			} else {
				println(res.body)
			}
		}

		conn.close() or {}

		if app.debug {
			println('======================')
		}
    }
}


struct Handler {
		func fn(Request) Response
}


// ===== functions ======

fn split2(s string, flag string) (string, string) {
	// split2('abc:def:xyz', ':') => 'abc', 'def:xyz'
	// split2('abc', ':') => 'abc', ''
	mut items := s.split(flag)
	if items.len == 1 {
		items << ''
	}
	// length of items must more than 2
	return items[0], items[1..].join(flag)
}

fn default_handler_func(req Request) Response {
	res := Response{
		status: 404
		body: '$req.path not found!'
	}
	return res
}

fn urldecode(query_str string) map[string]string {
	mut query := map[string]string
	mut s := query_str
	s = s.replace('+', ' ')
	items := s.split('&')
	for item in items {
		if item.len == 0 {
			continue
		}
		key, value := split2(item.trim_space(), '=')
		val := urllib.query_unescape(value) or {
			continue
		}
		query[key] = val
	}
	return query
}

fn readall(conn net.Socket, debug bool) ?string {
	mut message := ''
	mut total_size := 0
	for {
		buf := [1024]byte
		if debug {
			println('recv..')
		}
		n := C.recv(conn.sockfd, buf, 1024, 2)
		if debug {
			println('n: $n')
		}
		if n == 0 {
			break
		}
		bs, m := conn.recv(1024 - 1)
		total_size += m
		if debug {
			println('m: $m, total: $total_size')
		}
		if total_size > post_body_limit {
			return error('413')
		}
		ss := tos_clone(bs)
		message += ss
		if n == m {
			break
		}
	}
	return message
}

pub fn new_app(debug bool) App {
	run_ts := time.now().unix
	return App{debug: debug, run_ts: run_ts}
}

pub fn runserver(app App, port int) {
	mut p := port
	if port <= 0 || port > 65536 {
		p = 8012
	}
	server := Server{
		port: p
		app: app
	}
	server.run()
}

pub fn new_view(req Request, template string, ui string) View{
	if !(ui in ['element', 'mint', 'vant', 'antd', 'bootstrap', '', 'none']) {
		return View{error: 'ui just support `element, mint, vant, antd, bootstrap, none` now'}
	}
	if req.method != 'GET' {
		return View{error: 'view template only support GET method'}
	}
	if !template.ends_with('.html') {
		return View{error: 'template must be a .html file'}
	}
	if !os.exists(template) {
		return View{error: '$template template not found'}
	}

	mut content := ''
	template2 := template[..template.len-5] + '.val.html'
	if os.exists(template2) {
		ts0 := req.app.run_ts
		ts1 := os.file_last_mod_unix(template)
		ts2 := os.file_last_mod_unix(template2)
		if ts2 > ts1 && ts2 > ts0 {
			// use the cache file if available
			file_content := os.read_file(template2) or {
				return View{error: err}
			}
			content = file_content
		}
	}

	if content == '' {
		// compile the template
		file_content := os.read_file(template) or {
			return View{error: err}
		}
		content = file_content

		mut top := '<body>\n<!-- created by valval -->\n<div id="valapp" style="display: none">\n'
		top += '<div v-if="loading"> <p v-if="fail">Load failed, please check the network.</p><p v-else>loading...</p> </div>'
		top += '<div v-else>'
		content = content.replace_once('<body>', top)

		mut bottom := '\n</div></div>\n<!-- end of valapp -->\n'
		bottom += '<script src="https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"></script>\n'
		// bottom += '<script src="https://cdn.jsdelivr.net/npm/vue/dist/vue.min.js"></script>\n'
		bottom += '<script src="https://cdn.jsdelivr.net/npm/vue@2.6.0"></script>\n'

		if ui == 'element' {
			bottom +=  '<link href="https://cdn.jsdelivr.net/npm/element-ui@2.13.0/lib/theme-chalk/index.css" rel="stylesheet">\n'
			bottom += '<script src="https://cdn.jsdelivr.net/npm/element-ui@2.13.0/lib/index.js"></script>\n'
		} else if ui == 'mint' {
			bottom +=  '<link href="https://cdn.jsdelivr.net/npm/mint-ui@2.2.13/lib/style.min.css" rel="stylesheet">\n'
			bottom += '<script src="https://cdn.jsdelivr.net/npm/mint-ui@2.2.13/lib/index.js"></script>\n'
		} else if ui == 'vant' {
			bottom +=  '<link href="https://cdn.jsdelivr.net/npm/vant@2.2/lib/index.css" rel="stylesheet">\n'
			bottom += '<script src="https://cdn.jsdelivr.net/npm/vant@2.2/lib/vant.min.js"></script>\n'
		} else if ui == 'antd' {
			bottom +=  '<link href="https://cdn.jsdelivr.net/npm/ant-design-vue@1.4.10/dist/antd.min.css" rel="stylesheet">\n'
			bottom += '<script src="https://cdn.jsdelivr.net/npm/ant-design-vue@1.4.10/dist/antd.min.js"></script>\n'
		} else if ui == 'bootstrap' {
			bottom +=  '<link href="https://cdn.jsdelivr.net/npm/bootstrap@4.4.1/dist/css/bootstrap.min.css" rel="stylesheet">\n'
			bottom += '<script src="https://cdn.jsdelivr.net/npm/bootstrap@4.4.1/dist/js/bootstrap.min.js"></script>\n'
		}

		bottom += '<script>\n'
		bottom += '    vue = new Vue({\n'
		bottom += '        el: "#valapp",\n'
		bottom += '        data: function() {\n'
		bottom += '            return { \n'
		bottom += '                loading: true,\n'
		bottom += '                fail: false,\n'
		bottom += '            }\n'
		bottom += '        },\n'
		bottom += '        mounted: function() {\n'
		bottom += '            this.fetch()\n'
		bottom += '        },\n'
		bottom += '        methods: {\n'
		bottom += '            fetch: function(n) {\n'
		bottom += '                var n = n || 0\n'
		bottom += '                axios.get(location.href, {params: {$api_key_flag: "1"} })\n'
		bottom += '                .then(function (res) { for(key of Object.keys(res.data)){vue[key] = res.data[key]}; vue.loading = false })\n'
		bottom += '                .catch(function (err) { setTimeout(function(){ if(n<5){vue.fetch(n+1)}else{vue.fail=true} }, Math.random() * 1000 ) })\n'
		bottom += '            },\n'
		bottom += '        },\n'
		bottom += '    })\n'
		bottom += '    document.getElementById("valapp").style = ""\n'
		bottom += '</script>\n'
		bottom += '</body>'
		content = content.replace_once('</body>', bottom)
		os.write_file(template2, content)
	}
	view := View{
		req: req
		template: template
		ui: ui
		content: content
	}
	return view
}

pub fn response_ok(content string) Response {
	res := Response {
		status: 200
		body: content
	}
	return res
}

pub fn response_text(content string) Response {
	res := Response {
		status: 200
		body: content
		content_type: 'text/plain; charset=utf-8'
	}
	return res
}

pub fn response_json<T>(obj T) Response {
	str := json.encode(obj)
	res := Response {
		status: 200
		body: str
		content_type: 'application/json'
	}
	return res
}

pub fn response_json_str(data string) Response {
	res := Response {
		status: 200
		body: data
		content_type: 'application/json'
	}
	return res
}

pub fn response_file(path string) Response {
	// path := '${os.getwd()}/$path'
	if !os.exists(path) {
		return response_bad('$path file not found')
	}
	content := os.read_file(path) or { 
		println(err)
		return response_bad('$path read_file failed')
	}
	ext := os.ext(path)
	mime_map := {
		'.css': 'text/css; charset=utf-8',
		'.gif': 'image/gif',
		'.htm': 'text/html; charset=utf-8',
		'.html': 'text/html; charset=utf-8',
		'.jpg': 'image/jpeg',
		'.js': 'application/javascript',
		'.wasm': 'application/wasm',
		'.pdf': 'application/pdf',
		'.png': 'image/png',
		'.svg': 'image/svg+xml',
		'.xml': 'text/xml; charset=utf-8'
	}
	content_type := mime_map[ext]
	res := Response {
		status: 200
		body: content
		content_type: content_type
	}
	return res
}

pub fn response_redirect(url string) Response {
	res := Response {
		status: 301
		headers: {'Location': url}
	}
	return res
}

pub fn response_bad(msg string) Response {
	res := Response {
		status: 400
		body: msg
	}
	return res
}

pub fn response_view(view View) Response {
	req := view.req
	if req.is_page() {
		// first get request, return html page
		return response_ok(view.content)
	}
	// api request, return json data
	mut r := '{\n'
	for key in view.context.keys() {
		json_str := view.context[key]
		r += '  "$key" : $json_str ,\n'
	}
	r = r.trim_right(',\n')
	r += '\n}'
	return response_json_str(r)
}


// ========= Request Message Example =========
// POST /search HTTP/1.1  
// Accept: image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/vnd.ms-excel, application/vnd.ms-powerpoint, 
// application/msword, application/x-silverlight, application/x-shockwave-flash, */*  
// Referer: http://www.google.cn/  
// Accept-Language: zh-cn  
// Accept-Encoding: gzip, deflate  
// User-Agent: Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 2.0.50727; TheWorld)  
// Host: www.google.cn 
// Connection: Keep-Alive  
// Cookie: PREF=ID=80a06da87be9ae3c:U=f7167333e2c3b714:NW=1:TM=1261551909:LM=1261551917:S=ybYcq2wpfefs4V9g; 
// NID=31=ojj8d-IygaEtSxLgaJmqSjVhCspkviJrB6omjamNrSm8lZhKy_yMfO2M4QMRKcH1g0iQv9u-2hfBW7bUFwVh7pGaRUb0RnHcJU37y-
// FxlRugatx63JLv7CWMD6UB_O_r  
// 
// hl=zh-CN&source=hp&q=domety
// 
// 
// ======== Respose Message Example ==========
// 
// HTTP/1.1 200 OK
// Date: Mon, 23 May 2005 22:38:34 GMT
// Content-Type: text/html; charset=UTF-8
// Content-Encoding: UTF-8
// Content-Length: 138
// Last-Modified: Wed, 08 Jan 2003 23:11:55 GMT
// Server: Apache/1.3.3.7 (Unix) (Red-Hat/Linux)
// ETag: "3f80f-1b6-3e1cb03b"
// Accept-Ranges: bytes
// Connection: close

// <html>
// <head>
//   <title>An Example Page</title>
// </head>
// <body>
//   Hello World, this is a very simple HTML document.
// </body>
// </html>
// ============================================


