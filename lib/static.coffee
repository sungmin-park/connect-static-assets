Path = require 'path'
FS = require 'fs'

_ = require 'underscore'
Express = require "express"
ConnectAssets = require 'connect-assets'

findSync = (dirname)->
  files = FS.readdirSync dirname
  _.flatten _.compact _.map files, (file) ->
    file = Path.join dirname, file
    stats = FS.lstatSync file
    if stats.isDirectory() and not stats.isSymbolicLink()
      findSync file
    else if stats.isFile() 
      file

module.exports = (options) ->
  options = _.extend topLevelOnly: true, options
  connectAssets = ConnectAssets options
  assets_json = Path.join process.cwd(), 'assets.json'

  if options.build
    # TODO maybe needs cache in front of static
    expressStatic = Express.static Path.join process.cwd(), options.buildDir

    expressStatic.build = ->
      assets = {}
      _.forEach ['js', 'css', 'img'], (type) ->
        assets[type] = {}
        _.forEach findSync(prefix = Path.join process.cwd(), options.src, type),
          (file) ->
            return if Path.basename(file)[0] == '.'
            # remove path information before ~/assets/[js, css, img]
            file = file[prefix.length + 1 ..]
            if type isnt 'img'
              # To support various meta lang(coffee-script, stylus, ...)
              # extension should be removed if type isnt img
              file = file[...Path.extname(file).length * -1]
              # some less files cannot compile itself.
              # ex) bootstrap/accordion.less
              if options.topLevelOnly and Path.sep in file
                return
            assets[type][file] = options.helperContext[type] file
      FS.writeFileSync assets_json, JSON.stringify(assets, null, 4), 'utf-8'

    # change helper context in static manner  
    _.each(
      if FS.existsSync(assets_json)
        JSON.parse(FS.readFileSync(assets_json, 'utf-8'))
      else
        console.error "Cannt find #{assets_json}. Still work with connect-assets"
        {}
      (assets, type) ->
        options.helperContext[type] = (name) -> assets[name]
    )

    return expressStatic

  connectAssets
