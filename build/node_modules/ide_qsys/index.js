import fs from 'fs';
import net from 'net';

const timeoutPromise = (timeout) => new Promise((resolve) => setTimeout(resolve, timeout))

class Core {
  constructor({ip="",username="",pw="", comp=""} = {}) {
    this.ip = ip;
    this.username = username;
    this.pw = pw;
    this.comp = comp;
  }

  nt = "\u0000";

  add = (input, attribute) => {
    this[input] = attribute
  } 

  login = () => {
    return this.username && this.pw
    ?
    JSON.stringify({
      "jsonrpc": "2.0",
      "method": "Logon",
      "params": {
        "User": this.username,
        "Password": this.pw
      }
    })
    :
    false;
  };

  //parse string to push to core
  addCode = (comp, code, id, type) => {
    return JSON.stringify({
      "jsonrpc": "2.0",
      "id": id,
      "method": "Component.Set",
      "params": {
        "Name": comp,
        "Controls": [
          {
            "Name": type,
            "Value": code
          }
        ]
      }
    })
  };

  update = async (input, options = {}) => {

    // Destructure options
    let { id = 1234, type = "code" } = options;
  
    // Attempt to log in
    let loginSuccessful = this.login();
  
    let push = async () => {

      //return body
      return new Promise((resolve, reject) => {
        // Establish connection
        let client = new net.Socket();
      
        client.connect(1710, this.ip, async () => {
          client.setEncoding('utf8');

          if (loginSuccessful) client.write(loginSuccessful + this.nt);
    
          // Read file or update with input based on type
          if (type === "code") {
            fs.readFile(input, 'utf-8', (err, data) => {
              if (err) throw err;
              client.write(this.addCode(this.comp, data, id, type) + this.nt);
            });
          } else {
            client.write(this.addCode(this.comp, input, id, type) + this.nt);
          }

          //set up variables for parsing and returning
          let rtn = [];
          let fullString = "";

          // Event listeners
          client.on('data', (data) => {
            fullString += data;
          });
          client.on('close', () => {
            client.end();
          });
          // Wait for a period before ending the client
          await timeoutPromise(3000);
          client.end();

          for (let str of fullString.split("\x00")) {
            try {
              str ? rtn.push(JSON.parse(str)) : null;
            } catch (e) {
              console.log(`error parsing JSON with ${e}, on this string:\n\n${str}`)
            }
          }
          for (let res of rtn) {
            res.result ? resolve(res) : res.error && res.error.message == "Logon required" ? console.log('Error! Invalid credentials given!') : resolve(res);
          }
        });
      })
    };

    return await push();
  };

  //parse string to pull from core
  pullCode = (comp, id, type) => {

    //Get or GetControls based on type field
    if (!type) {
      return JSON.stringify({
        "jsonrpc": "2.0",
        "id": id,
        "method": "Component.GetControls",
        "params": {
          "Name": comp
        }   
      })
    } else {
      return JSON.stringify({
        "jsonrpc": "2.0",
        "id": id,
        "method": "Component.Get",
        "params": {
          "Name": comp,
          "Controls": [
            {
              "Name": type
            }
          ]
        }
      })
    }
  }

  //pull data from core
  retrieve = async (options) => {
    let getReturnData = async () => {
      return new Promise((resolve, reject) => {

        //handle optional arguments
        if (options) {
          options.id = options.id ? options.id : "1234";
        } else {
          options = {
            id: "1234",
            verbose: false,
          }
        };

        //handle login
        let login = this.login();
  
        let client = new net.Socket();
  
        client.connect(1710, this.ip, async () => {
          
          //check for login credentials
          this.login() ? client.write(login + this.nt) : null;
          //log based on type input
          if (options.verbose) {
            options.type ? console.log(`Retriving ${this.comp}'s ${options.type}`) : console.log(`Retrieving ALL controls from ${this.comp}`);
          }
          
          //api call based on options
          client.write(this.pullCode(this.comp, options.id, options.type) + this.nt);
          client.setEncoding('utf8');

          //set up variables for parsing and returning
          let rtn = [];
          let fullString = "";

          //concatenate return data
          client.on('data', (d) => {

            //log incoming, if verbose is selected
            options.verbose ? console.log(d) : null;
            //concat data into large string, for future parsing
            fullString += d
          });

          //handle socket errors
          client.on('error', () => reject(err));
          client.setTimeout(5000);
          client.on('timeout', () => {
            console.log('socket timed out');
            client.end();
          });
          //handle if socket gets closed
          client.on('close', () => {
            client.end();
          });      
          //wait, and then close socket
          await timeoutPromise(1500);
          client.end();


          //parse full string into array of JSON data
          //array of full string, split by null terminator
          for (let str of fullString.split("\x00")) {
            //confirm string isn't blank, push JSON to array
            try {
              str ? rtn.push(JSON.parse(str)) : null
            } catch (e) {
              console.log(`error parsing JSON with ${e}, on this string:\n\n${str}`)
            }
          };

          //if set to verbose, return all json, otherwise just the name and controls
          if (options.verbose) {
            resolve(rtn)
          } else {
            for (let res of rtn) {
              res.result ? resolve(res.result) : null;
            }  
          }
        })    
      })
    };
    //initialize function above
    let finalData = await getReturnData();
    
    //stream to file if option is selected
    if (options.output) {
      console.log(`creating file at ${options.output} with return data`)
      let f = fs.createWriteStream(options.output);
      f.write(JSON.stringify(finalData, null, 2));
    };
    return finalData;
  };
};

export default Core;
