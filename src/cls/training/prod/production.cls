Class training.prod.production Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="training.prod.production" LogGeneralTraceEvents="false">
  <Description></Description>
  <ActorPoolSize>2</ActorPoolSize>
  <Item Name="training.service.REST" Category="" ClassName="training.service.REST" PoolSize="0" Enabled="false" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="routeur" Category="" ClassName="EnsLib.MsgRouter.RoutingEngine" PoolSize="1" Enabled="false" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Host" Name="BusinessRuleName">training.prod.routeurRoutingRule</Setting>
  </Item>
</Production>
}

}
