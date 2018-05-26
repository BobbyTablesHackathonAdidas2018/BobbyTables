const request = require('request')
const bpmKey = 'bca4d13a3b1505181f0d029fcacea404'
const bpmUrl = 'https://api.getsongbpm.com/search/'
const urlJoin = require('url-join')
const url = require('url')
const querystring = require('querystring')
const puppeteer = require('puppeteer')
getNextSong()

async function getNextSong (bpm, seedSong) {
  let browser, page
  try {
    browser = await puppeteer.launch({
      headless: false
    })
    process.on('beforeExit', function () {
      browser.close()
    })
    const page = await browser.newPage()
    await page.focus('div')
    page.on('error', function (err) {
      console.error('Global error page', err)
    })
    page.on('response', async function (response) {
      try {
        const json = await response.json()
        console.log(json)
      } catch (e) {
        // console.log('request is not json')
      }
    })

    await page.goto('http://www.songkeybpm.com/Advanced')


  } catch (e) {
    console.error('Error on main', e)
  }

 /* const a = await new Promise(function (resolve, reject) {
    request.get(bpmUrl, {
      qs: {
      api_key: bpmKey,
        type: 'song',
      lookup: 'Metallica'
    }
  }, function (err, response) {
      if (err) return reject(err)
      resolve(response)
    })
  })*/

  console.log(a)
}