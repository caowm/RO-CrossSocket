unit RO.Net.TcpBase;

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

  TROUserObject = class
  private
    fStream: TStream;
    fStreamLen: Cardinal;
    fLenReaded: Cardinal;
  public
    constructor Create(); virtual;
    destructor Destroy(); override;

    property Stream: TStream read fStream write fStream;
    property StreamLen: Cardinal read fStreamLen write fStreamLen;
    property LenReaded: Cardinal read fLenReaded write fLenReaded;
  end;

  TROBaseCrossSocket = class(TCrossSocket)
  private
    fTimeout: Integer;
  protected
    procedure LogicReceived(AConnection: ICrossConnection; ABuf: Pointer; ALen: Integer); override;

    procedure ProcessROStream(AConnection: ICrossConnection); virtual;
    function CreateUserObject(AConnection: ICrossConnection): TROUserObject; virtual;
    function GetUserObject(AConnection: ICrossConnection): TROUserObject;
  public
    property Timeout: Integer read fTimeout write fTimeout;
  end;


  function ReverseCardinal(const Value: Cardinal): Cardinal;

implementation


function ReverseCardinal(const Value: Cardinal): Cardinal;
begin
  Result := (Value shr 24 and $000000FF) or (Value shr 8 and $0000FF00) or
    (Value shl 8 and $00FF0000) or (Value shl 24 and $FF000000);
end;


{ TROUserObject }

constructor TROUserObject.Create;
begin
  fStreamLen := 0;
end;

destructor TROUserObject.Destroy;
begin
  fStream.Free;
end;


{ TROBaseCrossSocket }

procedure TROBaseCrossSocket.ProcessROStream(AConnection: ICrossConnection);
begin
  //
end;

function TROBaseCrossSocket.CreateUserObject(
  AConnection: ICrossConnection): TROUserObject;
begin
  Result := TROUserObject.Create;
end;

function TROBaseCrossSocket.GetUserObject(
  AConnection: ICrossConnection): TROUserObject;
begin
  if (AConnection.UserObject = nil) then
    AConnection.UserObject := CreateUserObject(AConnection);
  Result := TROUserObject(AConnection.UserObject);
end;

procedure TROBaseCrossSocket.LogicReceived(AConnection: ICrossConnection;
  ABuf: Pointer; ALen: Integer);
var
  p: PByte;
  CrossData: TROUserObject;
begin
  p := ABuf;

  try
    CrossData := GetUserObject(AConnection);

    while (ALen > 0) and (CrossData.LenReaded < SizeOf(CrossData.StreamLen)) do
    begin
      CrossData.StreamLen := CrossData.StreamLen shl 8 + p^;
      CrossData.LenReaded := CrossData.LenReaded + 1;
      Inc(p);
      Dec(ALen)
    end;

    if (ALen > 0) then
      CrossData.Stream.Write(p^, ALen);

    if (CrossData.LenReaded = SizeOf(CrossData.StreamLen)) and
      (CrossData.Stream.Size >= CrossData.StreamLen) then
    begin
      CrossData.Stream.Position := 0;
      ProcessROStream(AConnection);
    end;
  except
    on E: Exception do
    begin
      AppendLog('ROCrossSocket Error: %s', [E.Message]);
      AConnection.Close();
    end;
  end;
end;

end.
