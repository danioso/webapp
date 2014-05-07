webapp
======

gulp config with CoffeScript, jade, stylus, browserify and tinypng


## Install

Unless previously installed you'll need Cairo. For system-specific installation view the [node-canvas wiki](https://github.com/LearnBoost/node-canvas/wiki/_pages).

```shell
bower install
npm install
```

Signup for an API Key from https://tinypng.com/developers

```shell
export WEBAPP_PNG_COMPRESSION_SERVICE_KEY="API_KEY"
```

## Tasks

#### Runing watch task and start server on localhost:9000 
```shell
gulp watch
```

#### Runing build task (minify and rev files)
```shell
gulp build
```

#### Runing build with tinypng compression service
```shell
gulp build --png-compression
```

## TODO

- [ ] Improvements
- [ ] Yeoman generator



