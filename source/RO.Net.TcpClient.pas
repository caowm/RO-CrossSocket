unit RO.Net.TcpClient;

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
  System.SyncObjs,
  RO.Net.TcpBase,
  Net.SocketAPI,
  Net.CrossSocket.Base,
  Net.CrossSocket,
  Utils.Logger,
  uROClasses,
  uROTransportChannel,
  uROClientIntf,
  uROUri,
  uROUrlSchemes;

type

  TROClientUserObject = class(TROUserObject)
  private
    fStreamEvent: TEvent;
  public
    constructor Create(); override;
    destructor Destroy(); override;
    property StreamEvent: TEvent read fStreamEvent;
  end;

  TROCrossClient = class(TROBaseCrossSocket)
  private
  protected
    procedure ProcessROStream(AConnection: ICrossConnection); override;
    function CreateUserObject(AConnection: ICrossConnection)
      : TROUserObject; override;
  public
    procedure SendStream(AConnection: ICrossConnection;
      const AStream: TStream);
    procedure ReadStream(AConnection: ICrossConnection;
      const AStream: TStream; ATimeout: Integer);
  end;

  { TROCrossTcpChannel }
  TROCrossTcpChannel = class(TROTransportChannel, IROTransport, IROTCPTransport)
  private
    fConnection: ICrossConnection;
    fHost: string;
    fPort: Integer;
    fTimeout: Integer;
    procedure CheckConnection();
  protected
    procedure IntDispatch(aRequest, aResponse: TStream); override;
    function GetTargetUri: TROUri; override;
    procedure SetTargetUri(const aUri: TROUri); override;
    { IROTransport }
    function GetTransportObject: TObject; override;
    { IROTCPTransport }
    function GetClientAddress: string;
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
    procedure Assign(aSource: TPersistent); override;
    property Connection: ICrossConnection read fConnection;
  published
    property Port: Integer read fPort write fPort;
    property Host: string read fHost write fHost;
    property Timeout: Integer read fTimeout write fTimeout;
    property DispatchOptions;
    property OnAfterProbingServer;
    property OnAfterProbingServers;
    property OnBeforeProbingServer;
    property OnBeforeProbingServers;
    property OnLoginNeeded;
    property OnProgress;
    property OnReceiveStream;
    property OnSendStream;
    property OnServerLocatorAssignment;
    property ProbeFrequency;
    property ProbeServers;
    property ServerLocators;
    property SynchronizedProbing;
    property TargetUrl;
  end;

var
  GlobalCrossSocket: TROCrossClient;

implementation

{ TROCrossTcpChannel }

procedure TROCrossTcpChannel.Assign(aSource: TPersistent);
var
  lSource: TROCrossTcpChannel;
begin
  inherited;
  if aSource is TROCrossTcpChannel then
  begin
    lSource := TROCrossTcpChannel(aSource);
    Host := lSource.Host;
    Port := lSource.Port;
    Timeout := lSource.Timeout;
  end;
end;

procedure TROCrossTcpChannel.CheckConnection;
var
  Event: TEvent;
begin
  if (fConnection = nil) or (fConnection.ConnectStatus <> csConnected) then
  begin
    fConnection := nil;
    Event := TEvent.Create(nil, False, False, '');

    GlobalCrossSocket.Connect(Host, Port,
      procedure(AConnection: ICrossConnection; ASuccess: Boolean)
      begin
        if ASuccess then
        begin
          AppendLog('Connect OK', [Host, Port]);
          fConnection := AConnection;
        end;
        Event.SetEvent;
      end);
    Event.WaitFor(Timeout);
    Event.Free;
  end;

  if (fConnection = nil) then
    raise Exception.Create('Connect Fail');
end;

constructor TROCrossTcpChannel.Create(aOwner: TComponent);
begin
  inherited;
  fTimeout := 10000;
  TargetUri.Protocol := URL_PROTOCOL_TCP;
end;

destructor TROCrossTcpChannel.Destroy;
begin
  fConnection := nil;
  inherited;
end;

function TROCrossTcpChannel.GetClientAddress: string;
begin
  Result := fConnection.PeerAddr;
end;

function TROCrossTcpChannel.GetTargetUri: TROUri;
begin
  Result := inherited GetTargetUri;
  Result.Host := fHost;
  Result.Port := fPort;
end;

function TROCrossTcpChannel.GetTransportObject: TObject;
begin
  Result := Self;
end;

procedure TROCrossTcpChannel.IntDispatch(aRequest, aResponse: TStream);
begin
  CheckConnection();
  GlobalCrossSocket.SendStream(fConnection, aRequest);
  GlobalCrossSocket.ReadStream(fConnection, aResponse, fTimeout);
end;

procedure TROCrossTcpChannel.SetTargetUri(const aUri: TROUri);
begin
  fHost := aUri.Host;
  fPort := aUri.Port;
  inherited;
  TargetUri.Protocol := URL_PROTOCOL_TCP;
end;

{ TROCrossClient }

function TROCrossClient.CreateUserObject(AConnection: ICrossConnection)
  : TROUserObject;
begin
  Result := TROClientUserObject.Create();
end;

procedure TROCrossClient.ProcessROStream(AConnection: ICrossConnection);
var
  lUserObject: TROClientUserObject;
begin
  lUserObject := TROClientUserObject(AConnection.UserObject);
  lUserObject.Stream.Position := 0;
  lUserObject.StreamEvent.SetEvent;
end;

procedure TROCrossClient.ReadStream(AConnection: ICrossConnection;
const AStream: TStream; ATimeout: Integer);
var
  lUserObject: TROClientUserObject;
begin
  lUserObject := TROClientUserObject(GetUserObject(AConnection));
  lUserObject.StreamEvent.ResetEvent;
  lUserObject.Stream := AStream;
  lUserObject.Stream.Position := 0;
  lUserObject.StreamLen := 0;
  lUserObject.LenReaded := 0;

  lUserObject.StreamEvent.WaitFor(ATimeout);
  lUserObject.Stream := nil;
end;

procedure TROCrossClient.SendStream(AConnection: ICrossConnection;
const AStream: TStream);
var
  lSize: Cardinal;
begin
  AStream.Position := 0;
  lSize := ReverseCardinal(AStream.Size);
  AConnection.SendBuf(lSize, Sizeof(lSize));
  AConnection.SendBuf(TMemoryStream(AStream).Memory^, AStream.Size);
end;

{ TROClientUserObject }

constructor TROClientUserObject.Create;
begin
  inherited;
  fStreamEvent := TEvent.Create(nil, True, False, '');
end;

destructor TROClientUserObject.Destroy;
begin
  fStreamEvent.Free;
  inherited;
end;

initialization
  GlobalCrossSocket := TROCrossClient.Create(0);

finalization
  FreeAndNil(GlobalCrossSocket);

end.
