
// module valval

import (
	net
)

const (
	HTTP_404 = 'HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\n\r\n404 Not Found'
	HTTP_500 = 'HTTP/1.1 500 Internal Server Error\r\nContent-Type: text/plain\r\n\r\n500 Internal Server Error'
	mime_types = {
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
)

// ===== structs ======

pub struct Request {
		method string
		path string
		query string
		body string
		headers map[string]string
}


pub struct Response {
		status int = 200
		body string = ''
		content_type string = 'text/html'
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


pub struct App {
		name string = 'valval_app'
	mut:
		router map[string]fn(req Request) Response
}

pub fn (app mut App) register(path string, func fn(req Request) Response) {
	app.router[path] = func
}

pub fn (app App) handle(method string, path string, query string, body string, headers map[string]string) Response {
	mut func := default_route_func
	if (path in app.router) {
		func = app.router[path]
	}
	req := Request{
		method: method
		path: path
		query: query
		body: body
		headers: headers
	}
	res := func(req)
	return res
}


pub struct Server {
		name string = 'valval server'
		address string = '0.0.0.0'
		port int = 1208
	mut:
		app App
}

// =================================
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

// hl=zh-CN&source=hp&q=domety

pub fn (server Server) run() {
    println('Running Valval app on http://$server.address:$server.port ...')
    listener := net.listen(server.port) or { panic('failed to listen') }
	println(listener)
    for {
		conn := listener.accept() or { panic('accept failed') }
		println(conn)
		mut first_line := conn.read_line()
		first_line = rnstrip(first_line)
		println(first_line)
		items := first_line.split(' ')
		println(items)
		if items.len < 2 {
			println('invalid data for http')
			conn.write(HTTP_500) or {}
			conn.close() or {}
			continue
		}
		method := items[0]
		url := items[1]
		path := url.all_before('?')
		query := url.all_after('?')
		println('$method, $url, $path, $query')
		mut headers := map[string]string
		for {
			mut header_line := conn.read_line()
			header_line = rnstrip(header_line)
			if header_line == '' {
				break
			}
			header_name, header_value := split2(header_line, ':')
			headers[header_name] = header_value
		}
		println(headers)
		body := conn.read_line() // todo read all remain
		println(body)
		
		res := server.app.handle(method, path, query, body, headers)

		mut result := 'HTTP/1.1 $res.status ${res.status_msg()}\r\n'
		result += 'Content-Type: $res.content_type\r\n'
		result += '${res.header_text()}\r\n\r\n'
		result += '$res.body'
        conn.write(result) or { 
			conn.write(HTTP_500) or {}
		}

		conn.close() or {}
		println('-----------')
    }
}
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
// =================================


// ===== functions ======

fn default_route_func(req Request) Response {
	res := Response{
		status: 404
		body: '$req.path not found!'
	}
	return res
}

fn rnstrip(s string) string {
	// rnstrip('abc\r\ndef') => 'abc'
	return s.all_before('\r').all_before('\n')
}


fn split2(s string, flag string) (string, string) {
	// split2('abc:def:xyz', ':') => 'abc', 'def:xyz'
	items := s.split(flag)
	return items[0], items[1..].join(flag)
}

// ==============================

fn main() {
	println('valval demo')
}
