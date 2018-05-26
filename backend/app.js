
const express = require('express')

const bodyParser = require('body-parser')
const cookieParser = require('cookie-parser')
const bpmService = require('./bpmService')
const http = require('http')
const port = 3000

const app = express()

// main()
async function main () {
  try {

    const track = await bpmService.getNextSong(120, 'Break the loop Coro de rua')
    console.log(track)
  } catch (e) {
    console.error('Failed')
  }
}

app.use(cookieParser())


app.use(bodyParser.json())
app.use(bodyParser.urlencoded({extended: false}))

const router = express.Router()

router.get('/nextSong', async function (req, res, next) {
  const bpm = req.query.bpm
  const song = req.query.song
  const artist = req.query.artist
  console.log(bpm, song, artist)
  try {
    const track = await bpmService.getNextSong(bpm, song + ' ' + artist)
    res.json(track)
  } catch (e) {
    console.error('Error in request', e)
    res.sendStatus(500)
  }
})
app.use('/', router)

app.use('', router)

// catch 404 and forward to error handler
app.use(function (req, res, next) {
  console.log('not found')
  var err = new Error('Not Found\n')
  err.status = 404
  res.redirect('/')
})

app.use(function (err, req, res, next) {
  console.error('error', err)
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


