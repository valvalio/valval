# Valval

Valval is the fastest web framework in V language. 

This means you can __develop__ a website ___quickly___ and __run__ it ___even faster___!

##### A simple demo:

```v
import valval

fn hello(req valval.Request) valval.Response {
	return valval.response_ok('hello world')
}

fn main() {
	mut app := valval.new_app(true)
	app.route('/', hello)
	valval.runserver(app, 8012)
}
```


## Installation

### Using Git
```
$ git clone https://github.com/taojy123/valval
$ mkdir -p ~/.vmodules
$ ln -s $(pwd)/valval ~/.vmodules/valval 
```

### Using VPM
Watchmen123456 has registered the module with vpm. 
Simply use the following if you have v on your PATH variable:
``` bash
$ v install watchmen123456.valval
```

***Note***: If you use vpm; you'll have to change the import to:
```
import watchmen123456.valval
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
	app.route('/', hello)
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

You can decide whether to use debug mode when calling `valval.new_app()`
```v
mut app := valval.new_app(true)  // debug mode
mut app := valval.new_app(false) // production mode
```
debug mode will print out more infomation while app running

### Service Port

You can decide the service port number when calling the `valval.runserver()`
```v
valval.runserver(app, 8012)  // listening 8012 port
valval.runserver(app, 80)    // listening 80 port
```
The valval server will bind `0.0.0.0` address, so you can visit the website by `127.0.0.1:Port` or `ServerIp:Port`

### Routing

Use the `App.route()` function to band a handler function to request path

The handler function should have a parameter of type `Request` and return a `Response`

```v
mut app := valval.new_app(true)

app.route('/', hello)   		         // http://127.0.0.1

app.route('/users', function1)        // http://127.0.0.1/users
app.route('/user/info', function2)    // http://127.0.0.1/user/info

app.route('POST:/book', function3)  // http://127.0.0.1/book by POST
app.route('DELETE:/book', function4)    // http://127.0.0.1/book by DELETE
app.route('/book', function5)         // http://127.0.0.1/book by other methods

app.route('*', function6)   		     // all remain

valval.runserver(app, 80)
```

### Accessing Request Data

Currently, only the following data can be parsed:

- query parameters by GET request; by `valval.Request.query[xxx]`
- `x-www-form-urlencoded` parameters by POST / PUT / PATCH request; by `valval.Request.form[xxx]`

```v
fn hello(req valval.Request) valval.Response {
	mut name = request.query['name']
	if name == '' {
		name = 'world'
	}
	return valval.response_ok('hello $name')
}

fn post_hello(req valval.Request) valval.Response {
	mut name = request.form['name']
	if name == '' {
		name = 'world'
	}
	return valval.response_ok('hello $name')
}

app.route('GET:/hello', hello)
app.route('POST:/hello', post_hello)
```

`valval.Request.get()` provides a quick way to get data whether it is from `query` or `form`. 

```v
fn hello(req valval.Request) valval.Response {
	name = request.get('name', 'world')  // default: 'world'
	return valval.response_ok('hello $name')
}

app.route('/hello', hello)
```

More types of request data will be supported in the future:
- parameters in url
- `multipart/form-data` by POST request
- `application/json` by POST request
- uploaded files

### Static Files

Use `valval.App.serve_static` to serve local files

```v
mut app := valval.new_app(true)

app.serve_static('/static/', './relative/path/to/static/')  
// visit http://127.0.0.1/static/xxx.js ...

app.serve_static('/static2/', '/absolute/path/to/static2/') 
// visit http://127.0.0.1/static2/yyy.css ...

valval.runserver(app, 80)
```

### Rendering Templates

Valval used a whole new idea to implement the template function; inspired by [Vue's](https://github.com/vuejs/vue) system.

Has the following advantages:

- You don't need to spend time learning how to use templates, if you have used `Vue` before.
- If you haven't used `Vue`, you also can [learn](https://vuejs.org/v2/guide/syntax.html) it fast, because it's so easy.
- It can integrate some commonly used UI frameworks, such as: `element`, `mint`, `vant`, `antd`, `bootstrap`...
- I don't need to spend time developing built-in templates 😁.

An example for template:

`server.v`:

```v
import valval
import json

struct User {
	name string
	age int
	sex bool
}

fn users(req valval.Request) valval.Response {

	// create a view by template file (`test6.html` can be a relative or absolute path)
	// use `element` (https://github.com/ElemeFE/element) as ui framework
	mut view := valval.new_view(req, 'users.html', 'element') or {
		return valval.response_bad(err)
	}

	users := [
		User{'Lucy', 13, false},
		User{'Lily', 13, false},
		User{'Jim', 12, true},
	]
	msg := 'This is a page of three user'

	// use view.set to bind data for rendering template
	// the second parameter must be a json string
	view.set('users', json.encode(users))
	view.set('msg', json.encode(msg))

	return valval.response_view(view)
}
```

`users.html`:

```html
<html>
    <head>
        <title>Users Page</title>
    </head>
    <body>
        <!-- Content in body can use template syntax -->
        <h3>{{msg}}</h3>
        <p v-for="u in users">
            <span>{{u.name}}</span> ,
            <span>{{u.age}}</span> ,
            <el-tag v-if="u.sex">Male</el-tag>
            <el-tag v-else>Female</el-tag>
        </p>
    </body>
</html>
```

### Redirects

Use `valval.response_redirect()` to generate a redirect response

```v
fn test1(req valval.Request) valval.Response {
	name = req.get('name', '')
	if name == '' {
		return valval.response_redirect('/not_found')
	}
	return valval.response_ok('hello $name')
}
```

### Responses

In addition to the responses mentioned above (`response_ok`,  `response_view`, `response_redirect`)

Valval also provides other response types, as follows:

```v
struct User {
	name string
	age int
	sex bool
}

fn text(req valval.Request) valval.Response {
	return valval.response_text('this is plain text response')
}

fn json(req valval.Request) valval.Response {
	user = User{'Tom', 12, true}
	return valval.response_json(user)
	// -> {"name": "Tom", "age": 12, "sex": true}
}

fn json_str(req valval.Request) valval.Response {
	user = User{'Tom', 12, true}
	user_str = json.encode(user)
	return valval.response_json_str(user_str)
	// -> {"name": "Tom", "age": 12, "sex": true}
}

fn file(req valval.Request) valval.Response {
	return valval.response_file('path/to/local/file')
}

fn bad(req valval.Request) valval.Response {
	return valval.response_bad('Parameter error!')
	// response with statu code 400
}

```



## Complete Example

- You can visit https://github.com/taojy123/valval/tree/master/example to see the complete example.
- And the official website of valval (https://valval.cool) is also written with the valval framework: https://github.com/taojy123/valval_website



## The Way to Install V Language

Valval framework currently supports the V language version is 0.1.24

Here are some ways to install V:

### 1. Download a prebuilt V package

Visit official home page https://vlang.io/ to download


### 2. Run V in docker [recommand]

```
docker run -it -p 8012:8012 --name vlang taojy123/vlang bash
```
It includes OpenSSL

### 3. Install V from source
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
Windows (Win10 Verified):
Source can be downloaded from: 
* https://www.openssl.org/source/
* https://github.com/openssl/

You can find a [Graphic installer](https://slproweb.com/products/Win32OpenSSL.html "32 and 64 bit available") if that's more to you're liking.


