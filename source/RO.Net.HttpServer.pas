unit RO.Net.HttpServer;

{******************************************************************************}
{                                                                              }
{            CrossSocket Components for RemObjects                             }
{                                                                              }
{                By caowm (remojects@qq.com)                                   }
{                                                                              }
{            Homepage: https://github.com/caowm                                }
{                                                                              }
{******************************************************************************}

interface

uses
  System.SysUtils,
  System.Classes,
  Utils.Logger,
  Net.SocketAPI,
  Net.CrossHttpParams,
  Net.CrossSocket.Base,
  Net.CrossSocket,
  Net.CrossHttpServer,
  uIPHttpHeaders,
  uROBinaryMemoryStream,
  uROClientIntf,
  uROServerIntf,
  uROBaseHTTPServer;

type

  TCrossHttpTransport = class(TInterfacedObject, IROTransport, IROTCPTransport,
    IROHTTPTransport, IROHTTPRequest, IROHTTPTransportEx)
  private
    fRequestInfo: ICrossHttpRequest;
    fResponseInfo: ICrossHttpResponse;
    fOverriddenPathInfo: string;
    fCanUseContentEncoding: Boolean;
    fIsHTTPs: Boolean;
  protected
    { IROHTTPRequest }
    function GetMethod: string;
    procedure SetAuthPassword(const Value: string);
    procedure SetAuthUsername(const Value: string);
    function GetAuthPassword: string;
    function GetAuthUsername: string;
    function Get_QueryString: string;
    procedure SetUsesAuthentication(const Value: Boolean);
    function GetUsesAuthentication: Boolean;
    function GetQueryString(aValue: string): string; overload;
    function Request_GetContentType: string;
    function IROHTTPRequest.GetContentType = Request_GetContentType;
    { IROHTTPTransport }
    procedure SetHeaders(const aName, aValue: string);
    function GetHeaders(const aName: string): string;
    function GetContentType: string;
    procedure SetContentType(const aValue: string);
    function GetUserAgent: string;
    procedure SetUserAgent(const aValue: string);
    function GetTargetUrl: string;
    procedure SetTargetUrl(const aValue: string);

    function GetPathInfo: string;
    procedure SetPathInfo(const aValue: String);
    function GetQueryString: string; overload;
    function GetQueryParameter(const aName: String): String;

    function GetLocation: string;
    function GetCanUseContentEncoding: Boolean;
    procedure SetCanUseContentEncoding(const aValue: Boolean);
    { IROTransport }
    function GetTransportObject: TObject;
    function GetClientAddress: string;
  public
    constructor Create(ARequest: ICrossHttpRequest;
      AResponse: ICrossHttpResponse; AIsHTTPs: Boolean);
    property RequestInfo: ICrossHttpRequest read fRequestInfo;
    property ResponseInfo: ICrossHttpResponse read fResponseInfo;
  end;

  TROCrossHTTPServer = class(TROBaseHTTPServer)
  private
    fCrossServer: ICrossHttpServer;
  protected
    procedure InternalRequest(Sender: TObject; ARequest: ICrossHttpRequest;
      AResponse: ICrossHttpResponse; var AHandled: Boolean);

    procedure InternalConnect(Sender: TObject; AConnection: ICrossConnection);

    procedure IntSetActive(const Value: Boolean); override;
    function IntGetActive: Boolean; override;

    function GetPort: Integer; override;
    procedure SetPort(const Value: Integer); override;
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy(); override;
    procedure Assign(Source: TPersistent); override;
    property CrossServer: ICrossHttpServer read fCrossServer;
  published
    property Port;
  end;

implementation

{ TROCrossHTTPServer }

procedure TROCrossHTTPServer.Assign(Source: TPersistent);
var
  lSource: TROCrossHTTPServer;
begin
  inherited;
  if Source is TROCrossHTTPServer then
  begin
    lSource := TROCrossHTTPServer(Source);
  end;
end;

constructor TROCrossHTTPServer.Create(aOwner: TComponent);
begin
  inherited;
  fCrossServer := TCrossHttpServer.Create(0);
  fCrossServer.OnRequest := InternalRequest;
  fCrossServer.OnConnected := InternalConnect;
end;

destructor TROCrossHTTPServer.Destroy;
begin
  inherited;
  fCrossServer := nil;
end;

function TROCrossHTTPServer.GetPort: Integer;
begin
  Result := fCrossServer.Port;
end;

procedure TROCrossHTTPServer.InternalConnect(Sender: TObject;
  AConnection: ICrossConnection);
begin
  AppendLog('Http Client %s connected.', [AConnection.PeerAddr]);
end;

procedure TROCrossHTTPServer.InternalRequest(Sender: TObject;
  ARequest: ICrossHttpRequest; AResponse: ICrossHttpResponse;
  var AHandled: Boolean);
var
  lRec: TIPHTTPResponseHeaders;
  Transport: IROHTTPTransportEx;
  RequestStream: TStream;
  ResponseStream: TROBinaryMemoryStream;
  lContentType, lName, lValue: string;
  I: Integer;
begin
  lRec := TIPHTTPResponseHeaders.Create;
  Transport := TCrossHttpTransport.Create(ARequest, AResponse, false);

//  AppendLog('%s', [ARequest.Body.ClassName]);
  if (ARequest.BodyType = btBinary) then
  begin
    RequestStream := TStream(ARequest.Body);
  end
  else if (ARequest.BodyType = btUrlEncoded) then
  begin
    lValue := THttpUrlParams(ARequest.Body).Encode();
    RequestStream := TROBinaryMemoryStream.Create(lValue);
  end
  else if (ARequest.BodyType = btMultiPart) then
  begin
    // AppendLog('%s', [ARequest.RawRequestText]);
    // THttpMultiPartFormData(ARequest.Body);
    raise Exception.Create('MultiPart is not supported for remobjects');
  end;

  ProcessRequest(Transport, RequestStream, ResponseStream, lRec);

  lContentType := lRec.ContentType;
  if SameText(lContentType, 'text/xml') then
  begin
    lContentType := lContentType + '; charset=utf-8';
    lRec.Headers.Values['Charset'] := 'utf-8';
  end;
  AResponse.ContentType := lContentType;
  AResponse.StatusCode := lRec.Code;
  // AResponse.ResponseText := lRec.Reason;  ???

  for I := 0 to lRec.Headers.Count - 1 do
  begin
    lName := lRec.Headers.Names[I];
    lValue := lRec.Headers.Values[lName];
    if SameText(lName, 'Content-Type') then
      Continue
    else
      AResponse.Header.Add(lName, lValue);
  end;

  AResponse.Send(ResponseStream,
    procedure(AConnection: ICrossConnection; ASuccess: Boolean)
    begin
      ResponseStream.Free;
      if (not ASuccess) then
      begin
        AppendLog('Send fail: %s', [AConnection.PeerAddr]);
        AConnection.Close;
      end;
    end);

  AHandled := True;
end;

function TROCrossHTTPServer.IntGetActive: Boolean;
begin
  Result := fCrossServer.Active;
end;

procedure TROCrossHTTPServer.IntSetActive(const Value: Boolean);
begin
  fCrossServer.Active := Value;
end;

procedure TROCrossHTTPServer.SetPort(const Value: Integer);
begin
  fCrossServer.Port := Value;
end;

{ TCrossHttpTransport }

constructor TCrossHttpTransport.Create(ARequest: ICrossHttpRequest;
AResponse: ICrossHttpResponse; AIsHTTPs: Boolean);
begin
  fRequestInfo := ARequest;
  fResponseInfo := AResponse;
  fIsHTTPs := AIsHTTPs;
end;

function TCrossHttpTransport.GetAuthPassword: string;
begin
  Result := fRequestInfo.Authorization;
end;

function TCrossHttpTransport.GetAuthUsername: string;
begin
  Result := fRequestInfo.Authorization;
end;

function TCrossHttpTransport.GetCanUseContentEncoding: Boolean;
begin
  Result := fCanUseContentEncoding;
end;

function TCrossHttpTransport.GetClientAddress: string;
begin
  Result := fRequestInfo.Connection.PeerAddr;
end;

function TCrossHttpTransport.GetContentType: string;
begin
  Result := fResponseInfo.ContentType;
end;

function TCrossHttpTransport.GetHeaders(const aName: string): string;
begin
  Result := fRequestInfo.Header[aName];
end;

function TCrossHttpTransport.GetLocation: string;
begin
  if fIsHTTPs then
    Result := 'https://' + fRequestInfo.HostName
  else
    Result := 'http://' + fRequestInfo.HostName
end;

function TCrossHttpTransport.GetMethod: string;
begin
  Result := fRequestInfo.Method;
end;

function TCrossHttpTransport.GetPathInfo: string;
begin
  if fOverriddenPathInfo <> '' then
    Result := fOverriddenPathInfo
  else
    Result := fRequestInfo.Path;
end;

function TCrossHttpTransport.GetQueryParameter(const aName: String): String;
begin
  Result := fRequestInfo.Params[aName];
end;

function TCrossHttpTransport.GetQueryString: string;
begin
  Result := fRequestInfo.RawPathAndParams;
end;

function TCrossHttpTransport.GetQueryString(aValue: string): string;
begin
  Result := fRequestInfo.Query[aValue];
end;

function TCrossHttpTransport.GetTargetUrl: string;
begin
  Result := fRequestInfo.Path;
end;

function TCrossHttpTransport.GetTransportObject: TObject;
begin
  Result := Self;
end;

function TCrossHttpTransport.GetUserAgent: string;
begin
  Result := fRequestInfo.UserAgent;
end;

function TCrossHttpTransport.GetUsesAuthentication: Boolean;
begin
  Result := fRequestInfo.Authorization <> '';
end;

function TCrossHttpTransport.Get_QueryString: string;
begin
  Result := fRequestInfo.RawRequestText;
end;

function TCrossHttpTransport.Request_GetContentType: string;
begin
  Result := fRequestInfo.ContentType;
end;

procedure TCrossHttpTransport.SetAuthPassword(const Value: string);
begin
  //
end;

procedure TCrossHttpTransport.SetAuthUsername(const Value: string);
begin
  //
end;

procedure TCrossHttpTransport.SetCanUseContentEncoding(const aValue: Boolean);
begin
  fCanUseContentEncoding := aValue;
end;

procedure TCrossHttpTransport.SetContentType(const aValue: string);
begin
  fResponseInfo.ContentType := aValue
end;

procedure TCrossHttpTransport.SetHeaders(const aName, aValue: string);
begin
  fResponseInfo.Header.Add(aName, aValue);
end;

procedure TCrossHttpTransport.SetPathInfo(const aValue: String);
begin
  fOverriddenPathInfo := aValue;
end;

procedure TCrossHttpTransport.SetTargetUrl(const aValue: string);
begin
  //
end;

procedure TCrossHttpTransport.SetUserAgent(const aValue: string);
begin
  fResponseInfo.Header.Add('Server', aValue);
end;

procedure TCrossHttpTransport.SetUsesAuthentication(const Value: Boolean);
begin
  //
end;

end.
