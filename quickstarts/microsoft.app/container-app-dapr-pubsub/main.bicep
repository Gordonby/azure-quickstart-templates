param location string = resourceGroup().location
param acrName string = ''

resource acr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
}

module buildSubscriber 'br/public:deployment-scripts/build-acr:1.0.1' = {
  name: 'buildAcrImage-linux-dapr-subscriber'
  params: {
    AcrName: acr.name
    location: location
    gitRepositoryUrl: 'https://github.com/dapr/quickstarts.git'
    gitRepoDirectory: 'tutorials/pub-sub/python-subscriber'
    gitBranch: 'master'
    imageName: 'python-subscriber'
  }
}

module buildReactapp 'br/public:deployment-scripts/build-acr:1.0.1' = {
  name: 'buildAcrImage-linux-dapr-reactApp'
  params: {
    AcrName: acr.name
    location: location
    gitRepositoryUrl: 'https://github.com/dapr/quickstarts.git'
    gitRepoDirectory: 'tutorials/pub-sub/react-form'
    gitBranch: 'master'
    imageName: 'react-form'
  }
}


module myenv 'br/public:app/dapr-containerapps-environment:1.0.1' = {
  name: 'pubsub'
  params: {
    location: location
    nameseed: 'pubsub-app'
    applicationEntityName: 'orders'
    daprComponentType: 'pubsub.azure.servicebus'
  }
}

module appSubscriber 'br/public:app/dapr-containerapp:1.0.1' = {
  name: 'subscriber'
  params: {
    location: location
    containerAppEnvName: myenv.outputs.containerAppEnvironmentName
    containerAppName: 'subscriber-orders'
    containerImage: buildSubscriber.outputs.image
    environmentVariables: pubSubAppEnvVars
    targetPort: 5001
  }
}

module appPublisher 'br/public:app/dapr-containerapp:1.0.1' = {
  name: 'publisher'
  params: {
    location: location
    containerAppEnvName: myenv.outputs.containerAppEnvironmentName
    containerAppName: 'publisher-checkout'
    containerImage: 'ghcr.io/gordonby/dapr-sample-pubsub-checkout:0.1'
    environmentVariables: pubSubAppEnvVars
    enableIngress: false
  }
}

var pubSubAppEnvVars = [ {
  name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
  value: myenv.outputs.appInsightsInstrumentationKey
}
{
  name: 'AZURE_KEY_VAULT_ENDPOINT'
  value: keyvault.properties.vaultUri
}
]

resource keyvault 'Microsoft.KeyVault/vaults@2022-07-01' = existing {
  name: 'yourkeyvault'
  location: location
}
