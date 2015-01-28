#= require vendor/jquery-2.0.3
#= require vendor/angular
#= require vendor/jquery.magnific-popup.min
#= require vendor/d3-3.4.11.min
#= require_self


$ ->
  $("a.modal-help-link").on("click", (event)->
    event.preventDefault()
    $(@).magnificPopup({type: 'ajax'})
    $(@).magnificPopup('open')
  )

adminApp = angular.module "adminApp", []

adminApp.controller "AdminIndexCtrl", ["$scope", "$location", "$q", ($scope, $location, $q) ->
  $scope.data = []
  $scope.readQuery = null
  $scope.writeSeriesName = null
  $scope.writeValues = null
  $scope.successMessage = "OK"
  $scope.alertMessage = "Error"
  $scope.authMessage = ""
  $scope.queryMessage = ""
  $scope.selectedPane = "data"

  $scope.writeData = () ->
    unless $scope.writeSeriesName
      $scope.error("Time Series Name is required.")
      return

    try
      values = JSON.parse($scope.writeValues)
    catch
      $scope.alertMessage = "Unable to parse JSON."
      $("span#writeFailure").show().delay(1500).fadeOut(500)
      return

    $q.when(parent.influxdb.writePoint($scope.writeSeriesName, values)).then (response) ->
      $scope.success("200 OK")

  $scope.readData = () ->
    $scope.data = []

    $q.when(window.parent.influxdb.queryDatabase($scope.readQuery)).then (response) ->
      data = response
      data.forEach (datum) ->
        $scope.data.push
          name: datum.name
          columns: datum.columns
          points: datum.points
          graphs: $scope.filteredColumns(datum).map (column) ->
            $scope.columnPoints(datum, column)
    , (response) ->
      $scope.queryMessage = "ERROR: #{response.responseText}"
      $("span#queryFailure").show().delay(2500).fadeOut(1000)

  $scope.error = (msg) ->
    $scope.alertMessage = msg
    $("span#writeFailure").show().delay(1500).fadeOut(500)

  $scope.success = (msg) ->
    $scope.successMessage = msg
    $("span#writeSuccess").show().delay(1500).fadeOut(500)

  $scope.filteredColumns = (datum) ->
    columns = []
    if datum.points.length > 0
      datum.points[0].forEach (value, n) ->
        columns.push datum.columns[n] unless (typeof value == "string" || value instanceof String)
    else
      columns = datum.columns
    columns.filter (d) -> d != "time" && d != "sequence_number"

  $scope.columnPoints = (datum, column) ->
    index = datum.columns.indexOf(column)
    name: column,
    points: datum.points.map (row) ->
      time: new Date(row[0])
      value: row[index]

  if $scope.username && $scope.password && $scope.database
    $scope.authenticate()
]

adminApp.directive "lineChart", [() ->
  restrict: "E",
  replace: false,
  scope:
    data: "=data",
    seriesName: "=seriesName"
  link: (scope, element, attrs) ->
    margin = parseInt(attrs.margin) || 20
    barHeight = parseInt(attrs.barHeight) || 20
    barPadding = parseInt(attrs.barPadding) || 5

    scope.render = (data, seriesName) ->
      return if (!data)

      margin = {top: 10, right: 0, bottom: 30, left: 50}
      width = 970 - margin.left - margin.right
      height = 200 - margin.top - margin.bottom

      x = d3.time.scale().range([0, width])
      y = d3.scale.linear().range([height, 0])
      xAxis = d3.svg.axis().scale(x).orient("bottom")
      yAxis = d3.svg.axis().scale(y).orient("left").ticks(5).tickFormat(d3.format("1.2s"))
      line = d3.svg.line().x((d) -> x(d.time)).y((d) -> y(d.value))

      svg = d3.select(element[0]).append("svg")
        .attr("width", width + margin.left + margin.right)
        .attr("height", height + margin.top + margin.bottom)
        .append("g")
          .attr("transform", "translate(" + margin.left + "," + margin.top + ")")

      x.domain(d3.extent(data, (d) -> d.time ))
      y.domain(d3.extent(data, (d) -> d.value ))

      svg.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + height + ")")
        .call(xAxis)

      svg.append("g")
        .attr("class", "y axis")
        .call(yAxis)

      # Label y-axis
      svg.append("text")
        .attr("class", "y label")
        .attr("text-anchor", "end")
        .attr("y", 6)
        .attr("dy", ".75em")
        .attr("transform", "rotate(-90)")
        .text(seriesName);

      svg.append("path")
        .datum(data)
        .attr("class", "line")
        .attr("d", line)

    scope.render(scope.data, scope.seriesName)
]

