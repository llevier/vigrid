# web-telnet

Simple telnet client that runs in a web browser. Requires hterm for the terminal emulator, and websockify as a backend to connect.

## Usage

`hterm_all.js` needs to be in the same folder as `index.html`.
Run `libapps/libdot/bin/concat.sh -i libapps/hterm/concat/hterm_all.concat -o hterm_all.js` to generate `hterm_all.js`.
To start the server, use `websockify/run --web=. 80 :23`.
The telnet daemon must be running at port 23.
