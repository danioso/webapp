"use strict"

# Gulp
g 				= require('gulp')
$ 				= require('gulp-load-plugins') lazy:false
$.args 			= require('yargs').argv
$.sprite 		= require('css-sprite').stream
$.through2 		= require('through2')
$.fs 			= require('fs')
$.pkg 			= require('./package.json')

# Vars
pngServiceKey 	= process.env.WEBAPP_PNG_COMPRESSION_SERVICE_KEY

# Arguments
pngService 		= Boolean $.args.pngCompression

if !pngServiceKey 
	$.util.log 'Before running gulp, remember to set the environment var WEBAPP_PNG_COMPRESSION_SERVICE_KEY' 
	$.util.log 'You can signup for an API Key from https://tinypng.com/developers'
	process.exit()

# Banner
banner = [
	'<!--'
	''
	'<%= pkg.homepage %>'
	'<%= pkg.name %> v<%= pkg.version %>'
	'<%= pkg.description %>'
	''
	'-->'
	''
].join '\n'
	
# Jade
g.task 'jade', ->

	g.src('app/*.jade')
		.pipe $.plumber()
		.pipe $.jade({pretty:true})
		.pipe g.dest('dist/')
		
# Stylus
g.task 'stylus', ->

	g.src('app/styles/**/*.styl')
		.pipe $.plumber()
		.pipe $.stylus({use: ['nib']})
		.pipe g.dest('dist/styles')

# Coffee
g.task 'coffee', ->

	g.src(['app/scripts/**/*.coffee']) 
		.pipe $.plumber()
		.pipe $.coffee({bare: true})
		.pipe g.dest('dist/scripts/')

# Browserify
g.task 'browserify', ['coffee'], ->

	g.src( 'dist/scripts/main.js' )
		.pipe $.plumber()
		.pipe $.browserify(
			shim: 
				'backbone':
					path: './dist/bower/backbone/backbone.js'
					exports: 'Backbone'
					depends:
						underscore: 'underscore'
				'underscore':
					path: './dist/bower/lodash/dist/lodash.js'
					exports: '_'

			insertGlobals: true
			debug: !$.util.env.production
		)
		.pipe g.dest('dist/scripts/')

# Bower dependencies
g.task 'bower', ['browserify'], ->

	g.src(['dist/bower/jquery/dist/jquery.min.js','dist/bower/jquery/dist/jquery.min.map']) 
		.pipe $.plumber()
		.pipe g.dest('dist/scripts/vendor/')

# Sprite
g.task 'sprites', ->
	
	g.src('app/images/sprite/*.png')
		.pipe $.plumber()
	    .pipe $.sprite({
			name: 'sprite.png'
			style: 'sprite.styl'
			cssPath: '../images'
			processor: 'stylus'
		})
		.pipe $.if('*.png', g.dest('app/images/'))
		.pipe $.if('*.styl', g.dest('app/styles/'))

# Images
g.task 'images', ->
	
	g.src('app/images/*.*')
		.pipe $.plumber()
		.pipe g.dest('dist/images/')

# Clean
g.task 'clean', ->

	g.src ['dist/**/*','!dist/bower{,/**}'], {read: false}
		.pipe $.clean()

# HTML Ref and Minify
g.task 'ref', ['default'], ->

	jsFilter = $.filter('**/*.js')
	cssFilter = $.filter('**/*.css')
	
	g.src('dist/*.html')
		
		.pipe $.plumber()
		.pipe $.useref.assets()

		# CSS
		.pipe cssFilter
		.pipe $.rev()
		.pipe $.minifyCss()
		.pipe cssFilter.restore()
		
		# JS
		.pipe jsFilter
		.pipe $.rev()
		.pipe $.uglify()
		.pipe jsFilter.restore()

		# Output assets
		.pipe g.dest('dist/')

		# Assets Manifest
		.pipe $.rev.manifest()

		# Useref replace
		.pipe $.useref.restore()
		.pipe $.useref()

		# HTML
		.pipe $.minifyHtml()

		# Output manifest and useref
		.pipe g.dest('dist/')

g.task 'rev', ['ref'], ->

	# TODO, change to async?
	manifest = $.fs.readFileSync('dist/rev-manifest.json').toString()
	manifest = JSON.parse manifest

	regexp = RegExp("\\b(" + Object.keys(manifest).join("|") + ")\\b", "g")
	
	# TODO, create a gulp-rev-manifest?
	g.src('dist/*.html')
		.pipe $.plumber()
		.pipe $.through2.obj((file, encoding, cb) ->

			file.contents = new Buffer(file.contents.toString().replace(regexp, (_, string) ->
				manifest[string]
			))

			@push file
			cb()
			return
		)
		.pipe $.header(banner, { pkg : $.pkg } )
		.pipe g.dest('dist/')

g.task 'rev-clean', ['rev'], ->

	# TODO, change to async?
	manifest = $.fs.readFileSync('dist/rev-manifest.json').toString()
	manifest = JSON.parse manifest

	assets = [
		'dist/styles/**.*'
		'dist/scripts/**.*'
		'dist/rev-manifest.json'
	]

	for key of manifest
		assets.push '!dist/' + manifest[key]

	# TODO, create a gulp-rev-manifest?
	g.src(assets)
		.pipe $.plumber()
		.pipe $.clean()

g.task 'image-min', ['rev-clean'], ->

	g.src('dist/images/*.png')
		.pipe $.plumber()

		# Depends on external API Service, only 500 request per month
		.pipe $.if(pngService, $.tinypng(pngServiceKey))

		# Extensions with bad compression D__D
		#.pipe $.imagemin({progressive:true,pngquant:true})
		#.pipe $.image()
		#.pipe $.optipng()
		
		.pipe g.dest('dist/images/')

	g.src('dist/images/*.jpg')
		.pipe $.plumber()
		.pipe $.imagemin({progressive:true})
		.pipe g.dest('dist/images/')

# Default
g.task 'default', ['jade', 'coffee', 'browserify', 'sprites', 'stylus', 'images', 'bower']

# Build
g.task 'build', ['clean'], ->

	g.start 'default', 'ref', 'rev', 'rev-clean', 'image-min'

# Deploy
g.task 'deploy', ['jade', 'stylus']

# Server
g.task 'connect', $.connect.server(
	root: [__dirname + "/dist"]
	port: 9000
	livereload: true
	open: 
		browser: 'Google Chrome'
)

# Static server, livereload and watch changes 
g.task 'watch', ['connect', 'default'], ->

	g.watch [
		'dist/*.html'
		'dist/scripts/*.js'
		'dist/styles/*.css'
		'dist/images/*.*'
	], (event)->

		g.src(event.path)
			.pipe $.connect.reload()

	g.watch [
		'app/*.jade'
		'app/layout/*.jade'
	], ['jade']

	g.watch [
		'app/styles/**/*.styl'
	], ['stylus']

	g.watch [
		'app/scripts/**/*.coffee'
	], ['coffee', 'browserify']

	g.watch [
		'app/images/sprite/*.*'
	], ['sprites']

	g.watch [
		'app/images/*.*'
	], ['images']

