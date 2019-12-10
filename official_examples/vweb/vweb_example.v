module main

import vweb

const (
	port = 6789
)

struct App {
pub mut:
	vweb vweb.Context // TODO embed
	cnt int
}

fn main() {
	app := App{}
	vweb.run(mut app, port)
	//vweb.run<App>(Port)
}

pub fn (app mut App) init() {
	app.vweb.handle_static('.')
}

pub fn (app & App) json_endpoint() {
	app.vweb.json('{"a": 3}')
}

pub fn (app mut App) index() {
	app.cnt ++
	println('index1')
	$vweb.html()
	println('index3')
}

pub fn (app & App) aa() {
	println('aa1')
	// app.vweb.html('Hello world aa')
	$vweb.html()
	println('aa3')
}

pub fn (app & App) text() {
	app.vweb.text('Hello world')
}

pub fn (app mut App) cookie() {
	app.vweb.text('Headers:')
	app.vweb.set_cookie('cookie', 'test')
	app.vweb.text(app.vweb.headers)
	app.vweb.text('Text: hello world')
}
