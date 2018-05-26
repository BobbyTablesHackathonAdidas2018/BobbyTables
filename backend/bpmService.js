const request = require('request')
const bpmKey = 'bca4d13a3b1505181f0d029fcacea404'
const bpmUrl = 'https://api.getsongbpm.com/search/'
const urlJoin = require('url-join')
const url = require('url') 
const querystring = require('querystring')
const puppeteer = require('puppeteer')
// getNextSong(100, 'Metallica')
module.exports = getNextSong
async function getNextSong (bpm, seedSong) {
  let returnResolve
  const returnPromise = new Promise(function (resolve, reject) {
    returnResolve = resolve
  })
  let browser, page
  try {
    browser = await puppeteer.launch({
      headless: false
    })
    process.on('beforeExit', function () {
      browser.close()
    })
    const page = await browser.newPage()
    page.on('error', function (err) {
      console.error('Global error page', err)
    })
    page.on('response', async function (response) {
      try {
        let json
        try {
          json = await response.json()
        } catch (e) {

        }
        if (response.request().url().startsWith('http://www.songkeybpm.com/Advanced/AdvancedQuery')) {
          returnResolve(json.trackItems[0])
        }
      } catch (e) {
        console.log(e)
        // console.log('request is not json')
      }
    })

    await page.goto('http://www.songkeybpm.com/Advanced')
    await page.type('input.advanced-seed-search-field', seedSong)
    await page.click('input.advanced-seed-search-field')
    await page.keyboard.press(String.fromCharCode(13))

    await page.waitForSelector('.searchedSeedsList .detailed-album-container')
    await page.click('.searchedSeedsList .detailed-album-container')

    await page.waitForSelector('.selectedSeedNode')
    await page.click('#advancedSearchInputContainer-BPM')
    await page.type('#primaryField-BPM', '' + bpm)
    await page.click('.as-search-button')

    return returnPromise
  } catch (e) {
    console.error('Error on main', e)
  }

}