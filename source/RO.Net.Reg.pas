unit RO.Net.Reg;

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

procedure register;

implementation

uses
  System.Classes,
  RO.Net.TcpClient,
  RO.Net.TcpServer,
  RO.Net.HttpServer;


procedure register;
begin
  RegisterComponents('RO CrossSocket',
                     [TROCrossTcpChannel,
                      TROCrossTcpServer,
                      TROCrossHttpServer]);
end;

end.
