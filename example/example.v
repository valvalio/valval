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
// v run example

import (
	valval
)


fn test1(req valval.Request) valval.Response {
	aa := req.query['aa']
	content := 'test1: aa = $aa'
	res := valval.text_response(content)
	return res
}

fn test2(req valval.Request) valval.Response {
	method := req.method
	aa := req.form['aa']
	content := '$method: aa = $aa'
	res := valval.text_response(content)
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
	res := valval.json_response(user)
	return res
}


fn main() {
	println('valval example')
	mut app := valval.App{}

	app.register('/test1', test1)
	app.register('/test2', test2)
	app.register('/test3', test3)

	valval.runserver(app, 8012)
}

