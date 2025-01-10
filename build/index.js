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
  let test = await core.update('./code/runtime.lua');
  console.log(test);
  return test.params.Status.Code == 0 ? "Successful update!" : "error updating!"
};


switch(process.env.mode) {
  case "pullRuntim":
    pullRuntime();
    break;
  case "pushFromFile":
    // console.log(await pushFromFile());
    console.log(core);
    break;
}



