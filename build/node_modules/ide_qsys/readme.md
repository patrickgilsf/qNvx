
# Description

> This is a nodeJS tool for uploading code (or component changes) to your Q-Sys core from your IDE

## Installation

```bash
npm install ide_qsys
```

## Add dependency

```js
const Core = require("ide_qsys");
//or with es6:
import Core from "ide_qys"
```

## Initialize new core instance

> this takes an object with 4 arguments

```js
let deployment = new Core({
  ip: "192.168.1.1", //ip address of core
  username: "TestUser", //if authenticated, username
  pw: 1234, //if authenticated, pin number
  comp: "TextController" //component name of code you're updating
})
```

## Authentication

Your Q-Sys core might be hardened with authentication for QRC.
> [!WARNING]
> this is separate from authenticaion on the core itself

Authentication is performed in Q-Sys Administator:
![Image](img/qsys-admin.png)

## Add arguments after initializing

> add function will add or modify argruments after initializing

```js
let deployment = new Core();

deployment.ip = "192.168.1.1";
deployment.username = "TestUser";
...etc

console.log(deployment);
```

## Push code to the core

create .lua file

```bash
touch updateMe.lua
```

add code to .lua file

```lua
print("this is me adding code")
```

use `update()` to update:

```js
deployment.update('updateMe.lua')
```

... plus 2 optional arguments:

```js
let options = {
  id: "5678", //if not specified, id is 1234
  type: //default is code, but possible to add any control
}
```

if you add an options.type, then the first argument has to be the value you are changing the component type to:

```js
 deployment.update(true, {type: "Audio.1.visibility"})
```

![Image](img/alternate-update.png)

## Pull data from core (NEW)

you can now pull data from core, and return to object, or stream to file:

```js
deployment.retrieve(options)
```

...same optional arguments above, plus `output` for a file name to stream to, as well as `verbose` for deeper logging, ability to return all data:

```js
let options = {
  id: "5678",
  type: "script.error.count", //if there is no type specified, it pull all controls via GetControls
  output: "data.json",
  verbose: true
}
```

example:

```js
let core = new Core({
  ip: "192.168.42.148",
  username: "QSC",
  pw: "5678",
  comp: "X32"
})

console.log(await core.retrieve({type: "script.error.count", verbose: true}));
```

will return:

```js
trying credentials....
Retriving X32's script.error.count
{"jsonrpc":"2.0","method":"EngineStatus","params":{"Platform":"Core 110f","State":"Active","DesignName":"Tutorial_Main","DesignCode":"XavSo9Z8KKC8","IsRedundant":false,"IsEmulator":false,"Status":{"Code":5,"String":"Initializing - 8 OK, 1 Fault, 1 Initializing"}}}
{"jsonrpc":"2.0","result":{"Name":"X32","Controls":[{"Name":"script.error.count","String":"0","Value":0.0,"Position":0.0}]},"id":"1234"}
[
  {
    jsonrpc: '2.0',
    method: 'EngineStatus',
    params: {
      Platform: 'Core 110f',
      State: 'Active',
      DesignName: 'Tutorial_Main',
      DesignCode: 'XavSo9Z8KKC8',
      IsRedundant: false,
      IsEmulator: false,
      Status: [Object]
    }
  },
  {
    jsonrpc: '2.0',
    result: { Name: 'X32', Controls: [Array] },
    id: '1234'
  }
]
server closed connection
```

and:

```js
console.log(await core.retrieve({type: "script.error.count", output: "test.json"}));
```

will return:

```js
trying credentials....
Retriving X32's script.error.count
creating file at test.json with return data
{
  Name: 'X32',
  Controls: [
    { Name: 'script.error.count', String: '0', Value: 0, Position: 0 }
  ]
}
server closed connection
```

...as well as print this data to a `test.json` file

Questions? Issues and PRs always welcome!
