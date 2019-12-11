
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

struct Request {
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

struct Handler {
	pub:
		func fn (req Request) Response
}


pub struct App {
		name string = 'valval_app'
	mut:
		router map[string]Handler
}

pub fn (app mut App) register(path string, func fn(req Request) Response) {
	app.router[path] = Handler{func}
}

pub fn (app App) handle(method string, path string, query string, body string, headers map[string]string) Response {
	mut func := default_handler_func
	if (path in app.router) {
		func = app.router[path].func
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

pub fn (server Server) run() {
    println('Running Valval app on http://$server.address:$server.port ...')
    listener := net.listen(server.port) or { panic('failed to listen') }
    for {
		conn := listener.accept() or { panic('accept failed') }
		lines := read_http_request_lines(conn)
		println(lines)
		// mut first_line := conn.read_line()
		mut first_line := lines[0]
		first_line = rnstrip(first_line)
		println(first_line)
		items := first_line.split(' ')
		println(items)
		if items.len < 2 {
			println('invalid data for http')
			conn.write(HTTP_500) or {}
			conn.close() or {}
			println('continue')
			continue
		}
		method := items[0]
		url := items[1]
		path := url.all_before('?')
		mut query := ''
		// if url contains '?'
		if url.split('?').len > 1 {
			query = url.all_after('?')
		}
		println('$method, $url, $path, $query')
		mut headers := map[string]string
		mut body := ''
		mut flag := true
		for line in lines[1..] {
			// mut line := conn.read_line()
			tline := rnstrip(line)
			if tline == '' {
				flag = false
			}
			if flag {
				header_name, header_value := split2(tline, ':')
				headers[header_name] = header_value
			} else {
				body += tline + '\r\n'
			}
		}
		body = body.trim('\r\n')
		println(headers)
		println(body)
		
		res := server.app.handle(method, path, query, body, headers)

		mut result := 'HTTP/1.1 $res.status ${res.status_msg()}\r\n'
		result += 'Content-Type: $res.content_type\r\n'
		result += '${res.header_text()}\r\n\r\n'
		result += '$res.body'
		println(result)

        conn.write(result) or { 
			conn.write(HTTP_500) or {}
		}

		conn.close() or {}
		println('--------------------')
    }
}


// ===== functions ======

fn default_handler_func(req Request) Response {
	res := Response{
		status: 404
		body: '$req.path not found!'
	}
	return res
}

fn rnstrip(s string) string {
	// rnstrip('abc\r\ndef') => 'abc'
	// return s.all_before('\r').all_before('\n')
	return s.trim_right('\r\n')
}


fn split2(s string, flag string) (string, string) {
	// split2('abc:def:xyz', ':') => 'abc', 'def:xyz'
	items := s.split(flag)
	return items[0], items[1..].join(flag)
}

// ==============================

fn main() {
	println('valval demo')
	app := App{}
	server := Server{
		port: 6789
		app: app
	}
	server.run()
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
// 
// hl=zh-CN&source=hp&q=domety
// 
// =================================
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
// =================================



fn read_http_request_lines(conn &net.Socket) []string {
	mut lines := []string
	mut buf := [1024]byte // where C.recv will store the network data

	for {
		mut res := '' // The buffered line, including the ending \n.
		mut line := '' // The current line segment. Can be a partial without \n in it.
		for {
			n := int(C.recv(conn.sockfd, buf, 1024-1, net.MSG_PEEK))
			//println('>> recv: ${n:4d} bytes .')
			if n == -1 { return lines }
			if n == 0 {	return lines }
			buf[n] = `\0`
			mut eol_idx := -1
			for i := 0; i < n; i++ {
				if int(buf[i]) == 10 {
					eol_idx = i
					// Ensure that tos_clone(buf) later,
					// will return *only* the first line (including \n),
					// and ignore the rest
					buf[i+1] = `\0`
					break
				}
			}
			line = tos_clone(buf)
			if eol_idx > 0 {
				// At this point, we are sure that recv returned valid data,
				// that contains *at least* one line.
				// Ensure that the block till the first \n (including it)
				// is removed from the socket's receive queue, so that it does
				// not get read again.
				C.recv(conn.sockfd, buf, eol_idx+1, 0)
				res += line
				break
			}
			// recv returned a buffer without \n in it .
			C.recv(conn.sockfd, buf, n, 0)
			res += line
			break
		}
		trimmed_line := res.trim_right('\r\n')
		if trimmed_line.len == 0 { break }
		lines << trimmed_line
	}

	return lines
}

