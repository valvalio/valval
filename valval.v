
module valval

import (
	net
	net.urllib
	json
	os
)

const (
	HTTP_404 = 'HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\n\r\n404 Not Found'
	HTTP_413 = 'HTTP/1.1 413 Request Entity Too Large\r\nContent-Type: text/plain\r\n\r\n413 Request Entity Too Large'
	HTTP_500 = 'HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\n\r\n500 Internal Server Error'
	MINE_MAP = {
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
	POST_BODY_LIMIT = 1024 * 1024 * 20  // 20MB
)

// ===== structs ======

pub struct Request {
	pub:
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


pub struct Response {
		status int = 200
		body string = ''
		content_type string = 'text/html; charset=utf-8'
		headers map[string]string
}

fn (res Response) header_text() string {
	// res.header_text() => '// Content-Encoding: UTF-8\r\nContent-Length: 138'
	mut lines := []string
	keys := res.headers.keys()
	for key in keys {
		value := res.headers[key]
		lines << '$key: $value'
	}
	text := lines.join('\r\n')
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


struct Handler {
		func fn(Request) Response
}


pub struct App {
	pub:
		name string = 'ValvalApp'
		debug bool = true
	mut:
		router map[string]Handler
		static_map map[string]string
}

pub fn (app mut App) register(path string, func fn(Request) Response) {
	app.router[path] = Handler{func}
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
		method: method
		path: path
		query: query
		form: form
		body: body
		headers: headers
	}
	handler := app.find_handler(path)
	func := handler.func
	res := func(req)
	return res
}

fn (app App) find_handler(path string) Handler {
	router := app.router
	if (path in router) {
		return router[path]
	}
	path2 := path.trim_right('/')
	if (path2 in router) {
		return router[path2]
	}
	path3 := path2 + '/'
	if (path3 in router) {
		return router[path3]
	}
	return Handler{default_handler_func}
}

pub fn (app mut App) serve_static(static_prefix string, static_root string) {
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


pub struct Server {
	pub:
		name string = 'ValvalServer'
		address string = '0.0.0.0'
		port int = 8012
	mut:
		app App
}

pub fn (server Server) run() {
	app := server.app
    println('${server.name} with ${app.name} running on http://$server.address:$server.port ...')
	println('working in: ${os.getwd()}')
	println('OS: ${os.user_os()}')
	println('Debug: ${app.debug}')
    // listener := net.listen(server.port) or { panic('failed to listen') }
    for {
    	listener := net.listen(server.port) or { panic('failed to listen') }
		conn := listener.accept() or { panic('accept failed') }
		listener.close() or {} // todo: do not close listener and recreate everytime
		if app.debug {
			println('===============')
			println(conn)
		}
		message := readall(conn, app.debug) or {
			println(err)
			if err == '413' {
				conn.write(HTTP_413) or {}
			} else {
				conn.write(HTTP_500) or {}
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
			conn.write(HTTP_500) or {}
			conn.close() or {}
			continue
		}
		first_line := lines[0].trim_space()
		items := first_line.split(' ')
		if items.len < 2 {
			println('invalid data for http')
			conn.write(HTTP_500) or {}
			conn.close() or {}
			continue
		}
		method := items[0]
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
			println('------------')
			println(headers)
			if body.len > 2000 {
				println(body[..2000])
			} else {
				println(body)
			}
		}
		
		res := app.handle(method, path, query, body, headers)

		mut result := 'HTTP/1.1 $res.status ${res.status_msg()}\r\n'
		result += 'Content-Type: $res.content_type\r\n'
		result += '${res.header_text()}'
		result += '\r\n'
		result += '$res.body'
		if app.debug {
			println('------------')
			if result.len > 2000 {
				println(result[..2000])
			} else {
				println(result)
			}
		}

        conn.write(result) or { 
			conn.write(HTTP_500) or {}
		}
		conn.close() or {}

		if app.debug {
			println('======================')
		}
    }
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
		if total_size > POST_BODY_LIMIT {
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
	return App{debug: debug}
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

pub fn response_file(path string) Response {
	// fpath := '${os.getwd()}/$path'
	fpath := path
	if !os.exists(fpath) {
		return Response{status: 404, body: '$fpath file not found! [404]'}
	}
	content := os.read_file(fpath) or { 
		println(err)
		return Response{status: 500, body: '500'}
	}
	ext := os.ext(fpath)
	content_type := MINE_MAP[ext]
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


