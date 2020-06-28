var express = require('express');
var os = require('os');

var app = express();
app.get('/patch', function(req, res) {
  const params = req.query
  const version = params.version
  res.sendFile(__dirname + "/src/json/codepush/patches.json")
})

app.get('/',function(req,res) {
  res.send("hello! server is running")
})

function getIPAdress() {
  let interfaces = os.networkInterfaces();
  for (var devName in interfaces) {
    var iface = interfaces[devName];
    for (var i = 0; i < iface.length; i++) {
      let alias = iface[i];
      if (alias.family === 'IPv4' && alias.address !== '127.0.0.1' && !alias.internal) {
        console.log(alias);
        return alias
      }
    }
  }
}

var server = app.listen(8082, function () {
  var port = server.address().port
  var address = getIPAdress()
  console.log("应用实例，访问地址为 http://%s:%s", address.address, port)
})
