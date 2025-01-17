import Core from 'ide_qsys';
import fs from 'fs';
import dotenv from 'dotenv';
dotenv.config();

let core = new Core({
  username: "QSC",
  pw: process.env.qsysPw,
  ip: "192.168.42.93",
  comp: "NVX_dev"
});

const pullRuntime = async () => {
  console.log("pulling runtime...");
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
}

const pushFromFile = async () => {
  const path = './code/runtime.lua';
  let updatedCodeToCore, errorCount, logs;
  try {
    //update file
    updatedCodeToCore = await core.update(path);

    //gather error count
    errorCount = await core.retrieve({type: "script.error.count"});

    //print output
    if (updatedCodeToCore.params.Status.Code == 0) {
      console.log(`${path} updated to ${core.ip} with $ ${errorCount.Controls[0].Value} errors\n`);
    };

    //gather and print logs
    logs = await core.retrieve({type: "log.history"});
    for (const str of logs.Controls[0].Strings ) {
      if (str == "" || !str) continue;
      console.log(str.replace(/\d+-\d+-\d+\w+:\d+:\d+\.\d\d\d/, '')); //removes timestamp
    };

    return {
      code: updatedCodeToCore.params.Status.Code == 0 ? 200 : 500,
      errors: errorCount
    }
  } catch(e) {
    console.error(e);
  }
};

const getConfig = async () => {
  const code = await core.retrieve();
  console.log(code);
  return code;
}

switch(process.env.mode) {
  case "pullRuntime":
    pullRuntime();
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



