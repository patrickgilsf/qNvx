import Core from 'ide_qsys';
import fs from 'fs';
import dotenv from 'dotenv';
dotenv.config();

let core = new Core({
  username: process.env.qUsername,
  pw: process.env.qPassword,
  ip: "", //add your IP address here
  comp: "qNVX"
});

const pullRuntime = async () => {
  if (this.ip == "") {
    console.log('add an ip address in index.js to push code')
    return;
  };
  console.log(`Pulling code from ${core.comp}...`);
  let comps = await core.retrieve();
  let rtn = {};

  for (let comp of comps.Controls) {
    if (comp.Name != "code") continue;
    rtn.success = true
    rtn.data = comp.String;
    fs.writeFileSync('./code/runtime.lua', rtn.data);
  };
  if (rtn.success) console.log("runtime updated!");
  return rtn;
};

const pushFromFile = async () => {
  if (this.ip == "") {
    console.log('add an ip address in index.js to push code')
    return;
  };
  const path = `./code/runtime.lua`;
  let updatedToCore, errorCount, logs;
  try {
      //update file
      updatedToCore = await core.update(path);

      //get error count
      errorCount = await core.retrieve({
          type: "script.error.count"
      });

      //print output
      // if (updatedToCore.params.Status.Code == 0) {
          console.log(`${path} updated to ${core.ip} with ${errorCount.Controls[0].Value} errors\n`);
      // };

      logs = await core.retrieve({type: "log.history"});
      for (const str of logs.Controls[0].Strings) {
          if (str == "" || !str) continue;
          console.log(str.replace(/\d+-\d+-\d+\w+:\d+:\d+\.\d\d\d/, '')); //removes timestamp
      }
  } catch (e) {
      console.log(e);
  }
};

const getConfig = async () => {
  if (this.ip == "") {
    console.log('add an ip address in index.js to push code')
    return;
  };
  const code = await core.retrieve();
  console.log(code);
  return code;
}

switch(process.env.mode) {
  case "pullRuntime":
    await pullRuntime();
    break;
  case "pushFromFile":
    await pushFromFile();
    break;
  case "getConfig": 
    await getConfig();
    break;
  defualt: 
    console.log(`you need to pass a mode argument to this script`);
    break;
}



