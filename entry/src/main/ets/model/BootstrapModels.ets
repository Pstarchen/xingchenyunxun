export class BootstrapController {
  id: string = ''
  name: string = ''
  canonicalEntry: string = ''
  timezone: string = ''
}

export class BootstrapServer {
  version: string = ''
  buildTime: string = ''
  apiVersion: number = 1
  minimumClientApiVersion: number = 1
  serverTime: string = ''
}

export class BootstrapPrincipal {
  authenticationType: string = ''
  username: string = ''
  role: string = ''
  tokenId: string = ''
  tokenPrefix: string = ''
  scopes: string[] = []
  serverIds: string[] = []
  expiresAt: string = ''
}

export class ClientBootstrap {
  controller: BootstrapController = new BootstrapController()
  server: BootstrapServer = new BootstrapServer()
  capabilities: string[] = []
  principal: BootstrapPrincipal = new BootstrapPrincipal()
}
