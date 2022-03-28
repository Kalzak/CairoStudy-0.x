If you don't have `python3.7` (for Ubuntu)
 - `sudo apt-add-repository ppa:deadsnakes/ppa`
 - `sudo apt-get update`
 - `sudo apt-get install python3.7 python3.7-dev python3.7-venv`

Recommended to use a virtual environment 
 - Example of path to use: `~/cairo_venv`
 - `python3.7 -m venv <path>`
 - `source <path>/bin/activate`

There are some prerequisites to install before pip packages
 - `sudo apt install -y libgmp3-dev`

Install the following pip packages
 - `pip3 install ecsda fastecdsa sympy`

Vim settings
 - Get vim files from [here](https://github.com/starkware-libs/cairo-lang/tree/master/src/starkware/cairo/lang/ide/vim)
 - Place in `~/vim/`

Test that compiling works
  - Create file named `test.cairo` with the following lines
    ```
    func main():
      [ap] = 1000; ap++
      [ap] = 2000; ap++
      [ap] = [ap - 2] + [ap - 1]; ap++
      ret
    end
    ```
  - Compile (this command should be executed in the venv)
    - `cairo-compile test.cairo --output test\_compiled.json`
  - Run
    - `cairo-run --program=test\_compiled.json --print\_output --print\_info --relocate\_prints`
  - Tracer
    - The Cairo tracer can be run by adding `--tracer` to the `cairo-run` above
    - It will then be accessible through `http://localhost:8100`
