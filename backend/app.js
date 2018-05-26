
const express = require('express')

const bodyParser = require('body-parser')
const cookieParser = require('cookie-parser')

const http = require('http')
const port = 3000

const app = express()

app.use(cookieParser())


app.use(bodyParser.json)
app.use(bodyParser.urlencoded({extended: false}))

// catch 404 and forward to error handler
app.use(function (req, res, next) {
  var err = new Error('Not Found')
  err.status = 404
  res.redirect('/')
})


app.use(function (err, req, res, next) {
  res.status(err.status || 500)
    .send({
      message: 'Error'
    })
})

const server = http.createServer(app)
server.listen(port)

server.on('error', function (err) {
  console.error('server error', err)
})

server.on('listening', function () {
  var addr = server.address()
  console.log('Listening on ', addr.port)
})

