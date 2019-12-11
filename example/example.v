module main

// git clone https://github.com/toajy123/valval
// v build module ./valval
// or 
// mkdir -p ~/.vmodules/
// mv ./valval ~/.vmodules/
// or
// ln -s /path/to/valval ~/.vmodules/valval

import (
	valval
)


fn main() {
	println('valval example')
	app := valval.App{}
	server := valval.Server{
		port: 9999
		app: app
	}
	server.run()
}

