module main

// git clone https://github.com/toajy123/valval
// ln -s $(pwd)/valval ~/.vmodules/valval  [or v build module ./valval]
// cd valval/example && v run example.v
// 
// curl http://127.0.0.1:8012

import (
	valval
	json
)


struct User {
	name string
	age int
	sex bool
}

struct Book {
	name string
	author string
}


fn index(req valval.Request) valval.Response {
	return valval.response_redirect('/test6')
}

fn hello(req valval.Request) valval.Response {
	return valval.response_ok('hello world')
}

fn test1(req valval.Request) valval.Response {
	name := req.query['name']
	content := 'test1: name = $name'
	res := valval.response_text(content)
	return res
}

fn test2(req valval.Request) valval.Response {
	method := req.method
	if method == 'DELETE' {
		return valval.response_bad('can not delete data!')
	}
	name := req.get('name', 'jim')
	content := '$method: name = $name'
	mut res := valval.response_text(content)
	res.set_header('x-test-key', 'test-value')
	return res
}

fn test3(req valval.Request) valval.Response {
	name := req.get('name', 'lily')
	age := req.get('age', '18')
	sex_str := req.get('sex', '0')
	mut sex := true
	if sex_str in ['0', ''] {
		sex = false
	}
	user := User{name, age.int(), sex}
	res := valval.response_json(user)
	return res
}

fn test4(req valval.Request) valval.Response {
	res := valval.response_file('template/test4.html')
	return res
}

fn post_test4(req valval.Request) valval.Response {
	name := req.form['name']
	age := req.form['age']
	url := '/test3/?name=$name&age=$age'
	return valval.response_redirect(url)
}

fn test5(req valval.Request) valval.Response {
	return valval.response_file('template/test5.html')
}

fn test6(req valval.Request) valval.Response {
	mut view := valval.new_view(req, 'template/test6.html', 'element') or {
		return valval.response_bad(err)
	}
	if req.is_page() {
		println('a user is viewing the test6 page')
	} else {
		println('api request by vue')
		user := User{'lilei', 14, true}
		view.set('user', json.encode(user))
		users := [
			User{'Lucy', 13, false},
			User{'Lily', 13, false},
			User{'Jim', 12, true},
		]
		total_count := users.len + 1
		view.set('users', json.encode(users))
		view.set('total_count', json.encode(total_count))
	}
	return valval.response_view(view)
}


fn main() {

	mut app := valval.new_app(true)

	app.serve_static('/static/', './static/')

	app.register('/', index)  // as same as: ('', index)
	app.register('/hello/world', hello)
	app.register('/test1', test1)
	app.register('/test2', test2)
	app.register('/test3', test3)
	app.register('/test4', test4)
	app.register('POST:/test4', post_test4)
	app.register('/test5', test5)
	app.register('/test6', test6)
	
	// app.register('*', index)

	valval.runserver(app, 8012)

}

