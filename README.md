# Valval

Valval is the fastest web framework for V language. 

It means you can develop a website fast and run it fast!


## Installation

### Install V language
```
$ git clone https://github.com/vlang/v
$ cd v
$ make
```

Install OpenSSL
```
macOS:
$ brew install openssl

Debian/Ubuntu:
$ sudo apt install libssl-dev openssl ca-certificates
```

Or use V in docker, it's include OpenSSL
```
docker run -it -p 8012:8012 --name vlang taojy123/vlang bash
```

### Install Valval
```
$ git clone https://github.com/toajy123/valval
$ ln -s $(pwd)/valval ~/.vmodules/valval 
```


## Quickstart

### A Minimal Application

A minimal Valval application looks something like this:
```v
// demo.v

module main

import valval

fn hello(req valval.Request) valval.Response {
	return valval.response_ok('hello world')
}

fn main() {
	mut app := valval.new_app(true)
	app.register('/', hello)
	valval.runserver(app, 8012)
}
```

Run server
```
$ v run demo.v
```

Then you can visit `http://127.0.0.1:8012/` to see the website
```
$ curl http://127.0.0.1:8012/
hello world
```

### Debug Mode

You can decide whether to use debug mode when calling `valval.new_app`
```v
mut app := valval.new_app(true)  // debug mode
mut app := valval.new_app(false) // production mode
```
debug mode will print out more infomation while app running

### Service Port

You can decide the service port number when calling the `valval.runserver`
```v
valval.runserver(app, 8012)  // listening 8012 port
valval.runserver(app, 80)    // listening 80 port
```
The valval server will bind `0.0.0.0` address, so you can visit the website by `127.0.0.1:Port` or `ServerIp:Port`

### Routing
### Accessing Request Data
### Static Files
### Rendering Templates
### Redirects
### Responses
### Json Support // todo


