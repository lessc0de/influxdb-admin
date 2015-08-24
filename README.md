# InfluxDB 0.8 and Prior Admin Interface

This is the source for the admin interface that ships with InfluxDB for **versions prior to 0.9**. Feel free to fork this repository,
make changes, and use your own variant of the interface with InfluxDB. It's currenly built using AngularJS.

### Running

The admin interface is built using Middleman, which uses an asset
pipeline for creating static assets.

If you've made changes, and want to test them locally do the following:

```
bundle exec middleman
```

This will run a server on port 4567.


### Building The Assets

If you've made changes, you can rebuild the assets by doing:

```
bundle exec middleman build
```

The resulting files will be in the folder called `build` and will mirror the layout of the files in `source`.


### Contributing

If you add something that you think should be part of the default admin interface, feel free to send us a pull request!
