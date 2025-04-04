# IO Module

### Introduction

**I/O** is very important in programming. Its needed to read and write to files and file descriptors.



###### Function Index

- **Console:**
  - `fflush`
  - `putchar`
  - `getchar`
  - `getbuff`
  - `getTermSize`
- **Files:**
  - `open`
  - `close`
  - `read`
  - `write`
  - `seek`
  - `access`
  - `chown`
  - `chmod`
  - `stat`
  - `remove`
  - `fopen`
  - `fclose`
  - `freopen`
- **Directories:**
  - `opendir`
  - `closedir`
  - `readdir`
  - `rewinddir`
- **Environment:**
  - `setenv`
  - `getenv`
  - `unsetenv`
  - `getcwd`



***

### Console

**Nyxian** is JavaScript based but doesnt have functionalities like JavaScripts `console`. It uses its modules and one of it is called `io`. **Nyxian** is designed to work in a CLI or in a Terminal Emulator. As **Nyxian** is a low level version of JavaScript you gonna jave to declare easier functions of the base functions ur self as you can see in following example

##### Example

```js
include("io");

// function to give feedback to the user
function print(msg) {
  let len = msg.length;
  for(let i = 0; i < len; i++) {
    io.putchar(msg.codePointAt(i));
  }
}

// function to get userinput
function readline(prompt)
{
  let buffer = "";
  print(prompt);
  while(true) {
    let data = io.getchar();
    let cdata = String.fromCharCode(data);
    if(cdata === "\r") {
      print("\n");
      return buffer;
    }
    if(cdata === 8 || data === 127) {
      if(buffer.length > 0) {
        buffer = buffer.slice(0, -1);
        print("\b \b");
      }
    } else {
      buffer += cdata;
      print(cdata);
    }
  }
}
```

***

### Files

**Nyxians** I/O functions are mostly like in C. The I/O Module features functions like `open`, `close`, `read`, `write`, `seek`, `stat`, `access`, `mkdir`, `rmdir`, `remove`, `chown`, `chmod`, `chdir`. In case you dont close a file descriptor they are **automatically closed on the end of the execution**

##### Example

```js
include("io");

// function to read a file at a path
function fs_read(path) {
  // does the function exist
  if(io.access(path, F_OK) != 0) {
    return 0
  }
  
  // opening file descriptor
  let fd = io.open(path, O_RDONLY);
  
  // seeking to the beginning of the file
  io.seek(fd, 0, SEEK_SET);
  
  // getting the files stat structure
  let stat = io.stat(fd);
  
  // reading the file
  let data = io.read(fd, stat.st_size);
  
  // closing the file descriptor
  io.close(fd);
  
  // returning the buffer which is a UTF8 char buffer hopefully
  return data.buffer;
}

// function to write to a file at a path
function fs_write(path, content) {
  let fd = 0;
  
  // does file exist? also open file descriptor
  if(io.access(path, F_OK) != 0) {
    fd = io.open(path, O_CREAT | O_WRONLY, S_IRUSR | S_IWUSR);
  } else {
    fd = io.open(path, O_TRUNC | O_WRONLY);
  }
  
  // seeking to the beginning of the file
  io.seek(fd, 0, SEEK_SET);
  
  // writing the data
  io.write(fd, content, content.length);
  
  // closing file descriptor
  io.close(fd);
}

io.mkdir("test", S_IRUSR | S_IWUSR);
let fd = io.open("test/file", O_RDWR | O_NOFOLLOW); //O_NOFOLLOW ensures that even if someone replaces test with a symlink in between, open() will fail on symlinks and not follow them.
io.write(fd, "meow!", 5);
print(io.read(fd, 5));
io.remove("test/file");
```
