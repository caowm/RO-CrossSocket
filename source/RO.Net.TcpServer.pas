unit RO.Net.TcpServer;

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
  RO.Net.TcpBase,
  Utils.Logger,
  Net.SocketAPI,
  Net.CrossSocket.Base,
  Net.CrossSocket,
  uROServer,
  uROClientIntf;

type

  { TROCrossServer }
  TROCrossServer = class(TROBaseCrossSocket)
  private
    fOwner: TComponent;
    fActive: Boolean;
    fPort: Integer;
    function GetActive: Boolean;
  protected
    procedure DispatchStream(AConnection: ICrossConnection);
    procedure SetActive(Value: Boolean);

    procedure ProcessROStream(AConnection: ICrossConnection); override;
    function CreateUserObject(AConnection: ICrossConnection)
      : TROUserObject; override;
  public
  published
    property Active: Boolean read GetActive write SetActive;
    property Port: Integer read fPort write fPort default 9088;
    property Owner: TComponent read fOwner write fOwner;
  end;

  TROCrossServerTransport = class(TInterfacedObject, IROTransport,
    IROTCPTransport)
  private
    fConnection: ICrossConnection;
  protected
    { IROTransport }
    function GetTransportObject: TObject;
    function GetClientAddress: string;
  public
    constructor Create(Connection: ICrossConnection);
    property Connection: ICrossConnection read fConnection;
  end;

  { TROCrossTCPServer }
  TROCrossTCPServer = class(TROServer)
  private
    fCrossServer: TROCrossServer;
    fKeepAlive: Boolean;
  protected
    function GetKeepAlive: Boolean; virtual;
    procedure SetKeepAlive(const Value: Boolean); virtual;
    procedure IntSetActive(const Value: Boolean); override;
    function IntGetActive: Boolean; override;
    function GetPort: Integer; override;
    procedure SetPort(const Value: Integer); override;
    function GetServerType: TROServerType; override;
  public
    constructor Create(aComponent: TComponent); override;
    destructor Destroy(); override;
    procedure Assign(Source: TPersistent); override;
    property CrossServer: TROCrossServer read fCrossServer;
  published
    property Active: Boolean read IntGetActive write IntSetActive;
    property Port: Integer read GetPort write SetPort default 9088;
    property KeepAlive: Boolean read GetKeepAlive write SetKeepAlive
      default True;
  end;

implementation

{ TROCrossServer }

function TROCrossServer.CreateUserObject(AConnection: ICrossConnection)
  : TROUserObject;
begin
  Result := TROUserObject.Create;
  Result.Stream := TMemoryStream.Create;
end;

procedure TROCrossServer.DispatchStream(AConnection: ICrossConnection);
var
  CrossData: TROUserObject;
  Response: TMemoryStream;
  Transport: IROTransport;
  StreamLen: Cardinal;
begin
  CrossData := TROUserObject(AConnection.UserObject);
  Response := TMemoryStream.Create;
  Transport := TROCrossServerTransport.Create(AConnection);
  try
    TROCrossTCPServer(fOwner).DispatchMessage(Transport, CrossData.Stream,
      Response);
    Response.Position := 0;
    StreamLen := Response.Size;
    // 字节序转为网络序
    StreamLen := ReverseCardinal(StreamLen);
    AConnection.SendBuf(StreamLen, SizeOf(StreamLen));
    // AConnection.SendStream容易报错
    AConnection.SendBuf(Response.Memory^, Response.Size);
  finally
    Response.Free;
    CrossData.Stream.Position := 0;
    CrossData.Stream.Size := 0;
    CrossData.StreamLen := 0;
    CrossData.LenReaded := 0;
  end;
end;

function TROCrossServer.GetActive: Boolean;
begin
  Result := fActive;
end;

procedure TROCrossServer.ProcessROStream(AConnection: ICrossConnection);
begin
  inherited;
  DispatchStream(AConnection);
end;

procedure TROCrossServer.SetActive(Value: Boolean);
begin
  if (Value <> Active) then
  begin
    CloseAll();
    fActive := False;
  end;
  if Value then
  begin
    Listen('0.0.0.0', Port);
    fActive := True;
  end;
end;

{ TROCrossTCPServer }

procedure TROCrossTCPServer.Assign(Source: TPersistent);
begin
  inherited;

end;

constructor TROCrossTCPServer.Create(aComponent: TComponent);
begin
  inherited;
  fCrossServer := TROCrossServer.Create(0);
  fCrossServer.Owner := Self;
end;

destructor TROCrossTCPServer.Destroy;
begin
  inherited;
  // FreeAndNil(fCrossServer);
end;

function TROCrossTCPServer.GetKeepAlive: Boolean;
begin
  Result := fKeepAlive;
end;

function TROCrossTCPServer.GetPort: Integer;
begin
  Result := fCrossServer.Port;
end;

function TROCrossTCPServer.GetServerType: TROServerType;
begin
  Result := rstTCP;
end;

function TROCrossTCPServer.IntGetActive: Boolean;
begin
  Result := fCrossServer.Active;
end;

procedure TROCrossTCPServer.IntSetActive(const Value: Boolean);
begin
  fCrossServer.SetActive(Value);
end;

procedure TROCrossTCPServer.SetKeepAlive(const Value: Boolean);
begin
  fKeepAlive := Value;
end;

procedure TROCrossTCPServer.SetPort(const Value: Integer);
begin
  fCrossServer.Port := Value;
end;

{ TROCrossServerTransport }

constructor TROCrossServerTransport.Create(Connection: ICrossConnection);
begin
  inherited Create();
  fConnection := Connection;
end;

function TROCrossServerTransport.GetClientAddress: string;
begin
  Result := fConnection.PeerAddr
end;

function TROCrossServerTransport.GetTransportObject: TObject;
begin
  Result := Self;
end;

end.
