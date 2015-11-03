#!/usr/bin/env coffee

_           = require("lodash")
fs          = require("fs")
path        = require("path")
exec        = require("child_process").exec
yaml        = require("js-yaml")
moment      = require("moment")
numeral     = require("numeraljs")
wkhtmltopdf = require("wkhtmltopdf")
handlebars  = require("handlebars")

translation = {}

# Helper functions
setLanguage = (lang) ->
  moment.locale(lang)
  try
    numeral.language(lang, require("numeraljs/languages/#{lang}"))
  catch e
  numeral.language(lang)
  translation = require(path.join(data.meta.destination.assetsFolder,"languages","#{lang}.json"))
  #translation = require("./languages/#{lang}.json")

replaceExtname = (filename, newExtname) ->
  return filename.replace(new RegExp(path.extname(filename).replace(/\./g, "\\."), "g"), newExtname)

roundCurrency = (value) ->
  if isNaN(value)
    value = 0
  return parseFloat(value.toFixed(2))


# Default language setting
#setLanguage("de")

# Business logic transformation
transformData = (data) ->

  _.defaults(data,
    order: {}
    receiver: {}
    items: []
    intro_text: ""
    outro_text: ""
  )

  data.order.language ?= "de"
  setLanguage(data.order.language)

  data.meta.assets = path.join(data.meta.destination.assetsFolder)
  data.order.template ?= "default"
  data.order.location ?= data.sender.town
  data.order.currency ?= "€"

  data.items = data.items.map((item) ->

    item = _.defaults(item,
      type : 'd'
    )
    

    return item
  )

  data


# Process arguments
inFilename = process.argv[2]
outFilename = replaceExtname(inFilename, ".pdf")

data = yaml.safeLoad(fs.readFileSync(inFilename, "utf8"))
data = transformData(data)

# Default language setting
#setLanguage("de")


templateFolder = data.meta.template.folder

tmpFilename = "#{templateFolder}/#{"xxxx-xxxx-xxxx".replace(/x/g, -> ((Math.random() * 16) | 0).toString(16))}.html"

# Prepare rendering
handlebars.registerHelper("plusOne", (value) -> 
  return value + 1
)
handlebars.registerHelper("number", (value) ->
  return numeral(value).format("0[.]0")
)
handlebars.registerHelper("money", (value) ->
  return "#{numeral(value).format("0,0.00")} #{data.order.currency}"
)

handlebars.registerHelper("moneyRound", (value) ->
  return "#{numeral(value).format("0,0.00")}"
)

handlebars.registerHelper("percent", (value) ->
  return numeral(value/100).format("0.00 %")
)
handlebars.registerHelper("fullPercent", (value) ->
  return numeral(value / 100).format("0 %")
)

handlebars.registerHelper("date", (value) ->
  return moment(value).format("LL")
)
handlebars.registerHelper("lines", (options) ->
  contents = options.fn()
  contents = contents.split(/<br\s*\/?>/)
  contents = _.compact(contents.map((a) -> a.trim()))
  contents = contents.join("<br>")
  return contents
)
handlebars.registerHelper("pre", (contents) ->
  return new handlebars.SafeString(contents.split(/\n/).map((a) -> handlebars.Utils.escapeExpression(a)).join("<br>"))
)
handlebars.registerHelper("t", (phrase) ->
  return translation[phrase] ? phrase
)

# Rendering
args ={
  output: "#{data.meta.destination.pdf}",
  marginLeft: "0mm",
  marginRight: "0mm",
}
#-- Header

if !!data.meta.destination.header 
  args.headerHtml = "file:///#{data.meta.destination.header}"
  template = handlebars.compile(fs.readFileSync("#{data.meta.template.header}", "utf8")) 
  fs.writeFileSync(data.meta.destination.header, template(data), "utf8")
# -- Footer
if !!data.meta.destination.footer
  args.footerHtml = "file:///#{data.meta.destination.footer}"
  template = handlebars.compile(fs.readFileSync("#{data.meta.template.footer}", "utf8")) 
  fs.writeFileSync(data.meta.destination.footer, template(data), "utf8")
#-- Body
template = handlebars.compile(fs.readFileSync("#{data.meta.template.body}", "utf8")) 
fs.writeFileSync(data.meta.destination.body, template(data), "utf8")

  
wkhtmltopdf("file:///#{data.meta.destination.body}", args, (err) ->
  if err
    console.error("Error creating #{data.meta.destination.pdf}")
    console.error(err)
  else
    console.log("Created #{data.meta.destination.pdf}")
  
  #fs.unlinkSync(tmpFilename)
)
