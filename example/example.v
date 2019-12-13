module main

// git clone https://github.com/toajy123/valval
// 
// v build module ./valval
// or 
// mkdir -p ~/.vmodules/
// mv ./valval ~/.vmodules/
// or
// ln -s /path/to/valval ~/.vmodules/valval
// 
// cd example && v run example.v

import (
	valval
)


fn index(req valval.Request) valval.Response {
	return valval.response_redirect('/test1')
}

fn test1(req valval.Request) valval.Response {
	aa := req.query['aa']
	content := 'test1: aa = $aa'
	res := valval.response_text(content)
	return res
}

fn test2(req valval.Request) valval.Response {
	method := req.method
	aa := req.form['aa']
	content := '$method: aa = $aa'
	res := valval.response_text(content)
	return res
}


struct User {
	name string
	age int
	sex bool
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
	println(user)
	res := valval.response_json(user)
	return res
}

fn test4(req valval.Request) valval.Response {
	res := valval.response_file('template/test4.html')
	return res
}

fn test5(req valval.Request) valval.Response {
	return valval.response_redirect('/test4/')
}


fn main() {
	println('valval example')

	mut app := valval.new_app(true)

	app.register('/', index)
	app.register('/test1', test1)
	app.register('/test2', test2)
	app.register('/test3', test3)
	app.register('/test4', test4)
	app.register('/test5', test5)
	app.serve_static('/static/', './static/')

	valval.runserver(app, 8012)

}

