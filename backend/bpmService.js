const request = require('request')
const puppeteer = require('puppeteer')
const memory = {

}
// getNextSong(100, 'Metallica')
module.exports = {getNextSong}
function getCacheKey (bpm, seedSong) {
  return '' + bpm + ' ' + seedSong
}
async function getNextSong (bpm, seedSong) {
  console.log('Searching for', bpm, seedSong)
  if (!bpm || !seedSong) {
    return Promise.reject(new Error('Missing param'))
  }
  const cache = memory[getCacheKey(bpm, seedSong)]
  if (cache) {
    return cache
  }

  let returnResolve, returnReject
  const returnPromise = new Promise(function (resolve, reject) {
    returnResolve = resolve
    returnReject = reject
  })
  memory[getCacheKey(bpm, seedSong)] = returnPromise
  let page, browser
  try {
    browser = await puppeteer.launch({
      headless: true/*,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox'
    ]*/
    })
    /*process.on('beforeExit', function () {
      browser.close()
    })*/
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
          const result = json.TrackItems[0]
          returnResolve(result)
          if (browser) {
            browser.close()
              .then(function () {
                console.log('browser closed')
              }, function (browser) {
                console.error('Error closing browser', browser)
              })
          }
        }
      } catch (e) {
        console.log(e)
      }
    })

    console.log('going to page')
    await page.goto('http://www.songkeybpm.com/Advanced')
    console.log('searching song')
    await page.type('input.advanced-seed-search-field', seedSong)
    await page.click('input.advanced-seed-search-field')
    await page.keyboard.press(String.fromCharCode(13))

    await page.waitForSelector('.searchedSeedsList .detailed-album-container', {timeout: 2000})
    await page.click('.searchedSeedsList .detailed-album-container')

    await page.waitForSelector('.selectedSeedNode')
    console.log('inserting bpm')
    await page.click('#advancedSearchInputContainer-BPM')
    await page.type('#primaryField-BPM', '' + bpm)
    await page.click('.as-search-button')

    return returnPromise
  } catch (e) {
    console.error('Error on main', e)
    returnReject(e)
    if (browser) {
      browser.close()
        .then(function () {
          console.log('browser closed')
        }, function (browser) {
          console.error('Error closing browser', browser)
        })
    }
    return returnPromise
  }

}
