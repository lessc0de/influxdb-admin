adminApp = angular.module "adminApp", ["ngCookies"]

adminApp.controller "AdminIndexCtrl", ["$scope", "$location", "$q", "$cookieStore", ($scope, $location, $q, $cookieStore) ->
  $scope.host = $location.search()["host"] || $cookieStore.get("host") || $location.host()
  $scope.port = $location.search()["port"] || $cookieStore.get("port")
  $scope.database = $location.search()["database"] || $cookieStore.get("database")
  $scope.username = $location.search()["username"] || $cookieStore.get("username")
  $scope.password = $location.search()["password"] || $cookieStore.get("password")
  $scope.ssl = $cookieStore.get("ssl") || false
  $scope.authenticated = false
  $scope.isClusterAdmin = false
  $scope.databases = []
  $scope.admins = []
  $scope.data = []
  $scope.readQuery = null
  $scope.writeSeriesName = null
  $scope.writeValues = null
  $scope.successMessage = "OK"
  $scope.alertMessage = "Error"
  $scope.authMessage = ""
  $scope.queryMessage = ""
  $scope.selectedPane = "databases"
  $scope.selectedSubPane = "users"
  $scope.newDbUser = {}
  $scope.interfaces = []
  $scope.databaseUsers = []
  $scope.retentionPolicies = []
  $scope.databaseUser = null
  $scope.successMessage = ""
  $scope.failureMessage = ""

  $scope.newAdminUsername = null
  $scope.newAdminPassword = null

  $scope.newUserPassword = null
  $scope.newUserPasswordConfirmation = null

  window.influxdb = null

  $scope.alertSuccess = (msg) ->
    $scope.successMessage = msg
    $("#alert-success").show().delay(2500).fadeOut(500)

  $scope.alertFailure = (msg) ->
    $scope.failureMessage = msg
    $("#alert-failure").show().delay(2500).fadeOut(500)

  $scope.humanize = (title) ->
    title.replace(/_/g, ' ').replace /(\w+)/g, (match) ->
      match.charAt(0).toUpperCase() + match.slice(1);

  $scope.setCurrentInterface = (i) ->
    $("iframe").prop("src", "/interfaces/#{i}")
    $scope.selectedPane = "data"

  $scope.showDefaultInterface = (databaseName) ->
    window.influxdb.database = databaseName
    $("iframe").prop("src", "/interfaces/default")
    $scope.selectedPane = "data"

  $scope.authenticateUser = () ->
    if $scope.database
      $scope.authenticateAsDatabaseAdmin()
    else
      $scope.authenticateAsClusterAdmin()

  $scope.authenticateAsClusterAdmin = () ->
    window.influxdb = new InfluxDB
      hosts: [$scope.host]
      port: $scope.port
      username: $scope.username
      password: $scope.password
      ssl: $scope.ssl

    # $q.when(window.influxdb.authenticateClusterAdmin()).then (response) ->
    $scope.authenticated = true
    $scope.isClusterAdmin = true
    $scope.isDatabaseAdmin = false
    $scope.selectedPane = "databases"
    $scope.selectedSubPane = "users"
    $scope.storeAuthenticatedCredentials()
    $scope.getDatabases()
    if $scope.database
      $scope.selectedDatabase = $scope.database
      $scope.showUsers()


  $scope.authenticateAsDatabaseAdmin = () ->
    window.influxdb = new InfluxDB
      host: $scope.host
      port: $scope.port
      username: $scope.username
      password: $scope.password
      database: $scope.database
      ssl: $scope.ssl

    # $q.when(window.influxdb.authenticateDatabaseUser($scope.database)).then (response) ->
    $scope.authenticated = true
    $scope.isDatabaseAdmin = true
    $scope.isClusterAdmin = false
    $scope.selectedPane = "databases"
    $scope.selectedSubPane = "users"
    $scope.selectedDatabase = $scope.database
    # $scope.setCurrentInterface("default")
    $scope.storeAuthenticatedCredentials()
    $scope.showUsers()

    # , (response) ->
      # $scope.authenticateAsClusterAdmin()

  $scope.storeAuthenticatedCredentials = () ->
    $cookieStore.put("username", $scope.username)
    $cookieStore.put("password", $scope.password)
    $cookieStore.put("database", $scope.database)
    $cookieStore.put("host", $scope.host)
    $cookieStore.put("port", $scope.port)
    $cookieStore.put("ssl", $scope.ssl)

  $scope.getDatabases = () ->
    $q.when(window.influxdb.showDatabases()).then (response) ->
      result = response.results[0]
      row = result.series[0]
      $scope.databases = row.values.map (value) ->
        name: value[0]

  $scope.getUsers = () ->
    $q.when(window.influxdb.getUsers()).then (response) ->
      $scope.users = response

  $scope.createDatabase = () ->
    $q.when(window.influxdb.createDatabase($scope.newDatabaseName)).then (response) ->
      $scope.alertSuccess("Successfully created database: #{$scope.newDatabaseName}")
      $scope.newDatabaseName = null
      $scope.getDatabases()
    , (response) ->
      $scope.alertFailure("Failed to create database: #{response.responseText}")

  $scope.deleteDatabase = (name) ->
    $q.when(window.influxdb.dropDatabase(name)).then (response) ->
      $scope.alertSuccess("Successfully removed database: #{name}")
      $scope.getDatabases()
    , (response) ->
      $scope.alertFailure("Failed to remove database: #{response.responseText}")

  $scope.authError = (msg) ->
    $scope.authMessage = msg
    $("span#authFailure").show().delay(1500).fadeOut(500)

  $scope.error = (msg) ->
    $scope.alertMessage = msg
    $("span#writeFailure").show().delay(1500).fadeOut(500)

  $scope.success = (msg) ->
    $scope.successMessage = msg
    $("span#writeSuccess").show().delay(1500).fadeOut(500)

  $scope.filteredColumns = (datum) ->
    datum.columns.filter (d) -> d != "time" && d != "sequence_number"

  $scope.columnPoints = (datum, column) ->
    index = datum.columns.indexOf(column)
    datum.points.map (row) ->
      time: new Date(row[0])
      value: row[index]

  $scope.getDatabaseUsers = () ->
    $q.when(window.influxdb.showUsers()).then (response) ->
      result = response.results[0]
      row = result.series[0]
      if row.values
        $scope.databaseUsers = row.values.map (value) ->
          name: value[0]
          isAdmin: value[1]
      else
        $scope.databaseUsers = []

  $scope.getRetentionPolicies = () ->
    $q.when(window.influxdb.showRetentionPolicies($scope.selectedDatabase)).then (response) ->
      result = response.results[0]
      row = result.series[0]
      if row.values
        $scope.retentionPolicies = row.values.map (value) ->
          name: value[0]
          duration: value[1]
          replicaN: value[2]
      else
        $scope.retentionPolicies = []

  $scope.createRetentionPolicy = () ->
    $q.when(window.influxdb.createRetentionPolicy($scope.selectedDatabase, $scope.newRetentionPolicyName, $scope.newRetentionPolicyDuration, $scope.newRetentionPolicyReplication, $scope.newRetentionPolicyIsDefault)).then (response) ->
      $scope.alertSuccess("Successfully created retention policy: #{$scope.newRetentionPolicyName}")
      $scope.newRetentionPolicyName = null
      $scope.newRetentionPolicyDuration = null
      $scope.newRetentionPolicyReplication = null
      $scope.newRetentionPolicyIsDefault = false
      $scope.getRetentionPolicies()
    , (response) ->
      $scope.alertFailure("Failed to create retention policy: #{response.responseText}")

  $scope.getDatabaseUser = () ->
    $q.when(window.influxdb.getDatabaseUser($scope.selectedDatabase, $scope.selectedDatabaseUser)).then (response) ->
      $scope.databaseUser = response

  $scope.showSelectedDatabase = () ->
    $scope.selectedPane = 'databases'
    $scope.selectedSubPane = 'users'
    $scope.selectedDatabaseUser = null
    $scope.getDatabaseUsers()
    $scope.getRetentionPolicies()

  $scope.showDatabases = () ->
    $scope.getDatabases()
    $scope.selectedPane = 'databases'
    $scope.selectedSubPane = 'users'
    $scope.selectedDatabase = null
    $scope.selectedDatabaseUser = null

  $scope.showDatabase = (database) ->
    $scope.selectedDatabase = database.name
    $scope.selectedDatabaseUser = null
    $scope.getDatabaseUsers()

  $scope.showDatabaseUsers = () ->
    $scope.selectedDatabaseUser = null
    $scope.selectedSubPane = "users"
    $scope.getDatabaseUsers()

  $scope.getContinuousQueries = () ->
    $q.when(window.influxdb.showContinuousQueries()).then (response) ->
      result = response.results[0]
      series = result.series.filter (row) ->
        row.name == $scope.selectedDatabase
      row = series[0]
      if row.values
        $scope.continuousQueries = row.values.map (value) ->
          id: value[0]
          query: value[1]
      else
        $scope.continuousQueries = []

  $scope.showContinuousQueries = () ->
    $scope.selectedDatabaseUser = null
    $scope.selectedSubPane = "continuousQueries"
    $scope.getContinuousQueries()

  $scope.showRetentionPolicies = () ->
    $scope.selectedDatabaseUser = null
    $scope.selectedSubPane = "retentionPolicies"
    $scope.getRetentionPolicies()

  $scope.showDatabaseUser = (databaseUser) ->
    $scope.selectedDatabaseUser = databaseUser.name
    $scope.getDatabaseUser()

  $scope.changeDbUserPassword = () ->
    if $scope.dbUserPassword != $scope.dbUserPasswordConfirmation
      $scope.alertFailure("Sorry, the passwords don't match.")
    else if $scope.dbUserPassword == null or $scope.dbUserPassword == ""
      $scope.alertFailure("Sorry, passwords cannot be blank.")
    else
      data = {password: $scope.dbUserPassword}
      $q.when(window.influxdb.updateDatabaseUser($scope.selectedDatabase, $scope.selectedDatabaseUser, data)).then (response) ->
        $scope.alertSuccess("Successfully changed password for '#{$scope.selectedDatabaseUser}'")
        $scope.dbUserPassword = null
        $scope.dbUserPasswordConfirmation = null
      , (response) ->
        $scope.alertFailure("Failed to change password for user: #{response.responseText}")

  $scope.changeClusterAdminPassword = () ->
    if $scope.clusterAdminPassword != $scope.clusterAdminPasswordConfirmation
      $scope.alertFailure("Sorry, the passwords don't match.")
    else if $scope.clusterAdminPassword == null or $scope.clusterAdminPassword == ""
      $scope.alertFailure("Sorry, passwords cannot be blank.")
    else
      data = {password: $scope.clusterAdminPassword}
      $q.when(window.influxdb.updateClusterAdmin($scope.selectedClusterAdmin, data)).then (response) ->
        $scope.alertSuccess("Successfully changed password for '#{$scope.selectedClusterAdmin}'")
        $scope.clusterAdminPassword = null
        $scope.clusterAdminPasswordConfirmation = null
      , (response) ->
        $scope.alertFailure("Failed to change password for cluster admin: #{response.responseText}")

  $scope.updateDatabaseUser = () ->
    data = {admin: $scope.databaseUser.isAdmin}
    $q.when(window.influxdb.updateDatabaseUser($scope.selectedDatabase, $scope.selectedDatabaseUser, data)).then (response) ->
      $scope.alertSuccess("Successfully updated database user '#{$scope.selectedDatabaseUser}'")
      $scope.getDatabaseUsers()
    , (response) ->
      $scope.alertFailure("Failed to update database user: #{response.responseText}")

  $scope.deleteDatabaseUser = (username) ->
    $q.when(window.influxdb.deleteDatabaseUser($scope.selectedDatabase, username)).then (response) ->
      $scope.alertSuccess("Successfully delete user: #{username}")
      $scope.getDatabaseUsers()
    , (response) ->
      $scope.alertFailure("Failed to delete user: #{response.responseText}")
]

adminApp.directive "ngConfirmClick", [ ->
  priority: -1
  restrict: "A"
  link: (scope, element, attrs) ->
    element.bind "click", (e) ->
      message = attrs.ngConfirmClick
      if message and not confirm(message)
        e.stopImmediatePropagation()
        e.preventDefault()
]
