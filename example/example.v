module main

// git clone https://github.com/toajy123/valval
// 
// v build module ./valval
// or
// ln -s $(pwd)/valval ~/.vmodules/valval
// 
// cd example && v run example.v

import (
	valval
)


struct User {
	name string
	age int
	sex bool
}


fn index(req valval.Request) valval.Response {
	return valval.response_redirect('/test4')
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
	res := valval.response_text(content)
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
	println(user)
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


fn main() {

	mut app := valval.new_app(true)

	app.serve_static('/static/', './static/')

	app.register('/', index)  // as same as: ('', index)
	app.register('/test1', test1)
	app.register('/test2/info', test2)
	app.register('/test3', test3)
	app.register('/test4', test4)
	app.register('POST:/test4', post_test4)
	
	// app.register('*', index)

	valval.runserver(app, 8012)

}

