type HttpMethods = 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE'
type BaseResource = {
  path: (args: any) => string
  names: string[]
  Methods?: HttpMethods
  Params?: { [method in HttpMethods]?: any }
  Return?: { [method in HttpMethods]?: any }
}
export async function railsApi<
  Method extends Exclude<Resource['Methods'], undefined>,
  Resource extends BaseResource,
  Params extends Exclude<Resource['Params'], undefined>[Method],
  Return extends Exclude<Resource['Return'], undefined>[Method]
>(method: Method, { path, names }: Resource, params: Params): Promise<{ status: number, json: Return }> {
  const tag = document.querySelector<HTMLMetaElement>('meta[name=csrf-token]')
  const paramsNotInNames = Object.keys(params).reduce<object>((ps, key) => names.indexOf(key) === - 1 ? { ...ps, [key]: params[key] } : ps, {})
  const searchParams = new URLSearchParams()
  for (const name of Object.keys(paramsNotInNames)) {
    searchParams.append(name, paramsNotInNames[name])
  }
  const query = method === 'GET' && Object.keys(paramsNotInNames).length ? `?${searchParams.toString()}` : ''
  const body = method === 'GET' ? undefined : JSON.stringify(paramsNotInNames)
  const response = await fetch(path(params) + query, {
    method,
    body,
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-CSRF-Token': tag.content
    }
  })
  const json = await response.json() as Return
  return new Promise((resolve) => resolve({ status: response.status, json: json }))
}
