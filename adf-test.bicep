// Define parameters for the script

@description('Name of the pipeline for data copy activity.')
param pipelineName string = 'db_rais_copy_futura'

@description('User Id for the source SQL Server.')
@secure()
param sqlsourceUserId string

@description('Password for the source SQL Server.')
@secure()
param sqlsourcePassword string

@description('User Id for the sink Azure SQL Database.')
@secure()
param sqlsinkUserId string

@description('Password for the sink Azure SQL Database.')
@secure()
param sqlsinkPassword string

@description('Server for the source SQL Server.')
@secure()
param sourceSqlServer string

@description('Server for the sink Azure SQL Database.')
@secure()
param sinkSqlServer string
param integrationRuntimeName string = 'azure copy activity'

// Define variable names for clarity
var linkedServiceSourceName = 'ls_raissql'
var linkedServiceSinkName = 'ls_futurasql'
var sourceDatasetName = 'ds_raisdataset'
var sinkDatasetName = 'ds_futuradataset'
var dataFactoryName = 'futuradf'

// Define variables for source server and database
var sourceServer = sourceSqlServer
var sourceDatabase = 'rais'

// Define variables for sink server and database
var sinkServer = sinkSqlServer
var sinkDatabase = 'FUTURA_DEV_NONEC_DB'

// Defining existing ADF 
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

resource integrationRuntime 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  name: integrationRuntimeName
  properties: {
    type: 'Managed'
  managedVirtualNetwork: {
    referenceName: 'string'
    type: 'ManagedVirtualNetworkReference'
  }
    typeProperties: {
      computeProperties: {
        location: 'East US'
        dataFlowProperties: {
          computeType: 'General'
          coreCount: 8
          timeToLive: 10
          cleanup: false
          customProperties: []
        }
        pipelineExternalComputeScaleProperties: {
          timeToLive: 60
          numberOfPipelineNodes: 1
          numberOfExternalNodes: 1
        }
      }
    }
    
  }
}



// Define linked service for the source (SQL Server)
resource dataFactoryLinkedServiceSource 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  parent: dataFactory
  name: linkedServiceSourceName
  properties: {
    type: 'SqlServer'
    typeProperties: {
      // Use variables for sourceServer and sourceDatabase
      connectionString: 'Server=${sourceServer};Database=${sourceDatabase};User Id=${sqlsourceUserId};Password=${sqlsourcePassword};'
    }
    connectVia: {
      referenceName: 'copyactivity'
      type: 'IntegrationRuntimeReference'
    }
  }
}


// Define linked service for the sink (Azure SQL Database)
resource dataFactoryLinkedServiceSink 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  parent: dataFactory
  name: linkedServiceSinkName
  properties: {
    type: 'AzureSqlDatabase'
    typeProperties: {
      // Use variables for sinkServer and sinkDatabase
      connectionString: 'Server=${sinkServer};Database=${sinkDatabase};User Id=${sqlsinkUserId};Password=${sqlsinkPassword};'
    }
    connectVia: {
      referenceName: 'copyactivity'
      type: 'IntegrationRuntimeReference'
    }
  }
}

// Define dataset for the source
resource dataFactorySourceDataset 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  parent: dataFactory
  name: sourceDatasetName
  properties: {
    linkedServiceName: {
      referenceName: dataFactoryLinkedServiceSource.name
      type: 'LinkedServiceReference'
    }
    annotations: []
    type: 'SqlServerTable'
    schema: []
    typeProperties: {
      table: 'rig_master'
    }
  }
}

// Define dataset for the sink
resource dataFactorySinkDataset 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  parent: dataFactory
  name: sinkDatasetName

  properties: {
    linkedServiceName: {
      referenceName: dataFactoryLinkedServiceSink.name
      type: 'LinkedServiceReference'
    }
    annotations: []
    type: 'AzureSqlTable'
    schema: []
    typeProperties: {
      table: 'rig_master'
    }
  }
}

resource pipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  parent: dataFactory
  name: pipelineName
  properties: {
    activities: [
      {
        name: 'cp_raistofutura'
        type: 'Copy'
        dependsOn: []
        policy: {
          timeout: '0.12:00:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          source: {
            type: 'AzureSqlSource'
            queryTimeout: '02:00:00'
            partitionOption: 'None'
          }
          sink: {
            type: 'AzureSqlSink'
            writeBehavior: 'insert'
            sqlWriterUseTableLock: false
            tableOption: 'autoCreate'
            disableMetricsCollection: false
          }
          enableStaging: false
          translator: {
            type: 'TabularTranslator'
            typeConversion: true
            typeConversionSettings: {
              allowDataTruncation: true
              treatBooleanAsNumber: false
            }
          }
        }
        inputs: [
          {
            referenceName: dataFactorySourceDataset.name
            type: 'DatasetReference'
            parameters: {}
          }
        ]
        outputs: [
          {
            referenceName: dataFactorySinkDataset.name
            type: 'DatasetReference'
            parameters: {}
          }
        ]
      }
    ]
    policy: {
      elapsedTimeMetric: {}
    }
    annotations: []
  }
}

resource dataFactoryPipelineTrigger 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: 'futura_dailytrigger'
  parent: dataFactory
  properties: {
    annotations: []
    type: 'ScheduleTrigger'
    pipelines: [
      {
        parameters: {}
        pipelineReference: {
          name: pipeline.name
          referenceName: pipeline.name
          type: 'PipelineReference'
        }
      }
    ]
    typeProperties: {
      recurrence: {
        frequency: 'Day'
        interval: 1
        startTime: '2024-01-15T12:12:00'  // Adjust the start time as needed
        timeZone: 'India Standard Time'
        schedule: {
          minutes: [45]
          hours: [20]
        }
      }
    }
  }
}
