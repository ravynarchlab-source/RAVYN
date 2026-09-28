-- RAVYN DIRECT v1.2 EXPLOIT CORE · SLAYERS 2 · DIRECT RELEASE (built on v1.0.1 Premium UI)
-- Each subsystem compiles in its own Luau chunk to stay below Xeno/Luau local-register limits.
local G=(getgenv and getgenv()) or _G
G.__RAVYN_CTX={Hooks={}}
local CTX=G.__RAVYN_CTX
local Players=game:GetService("Players")
local player=Players.LocalPlayer or Players.PlayerAdded:Wait()
local pg=player:WaitForChild("PlayerGui",10)
local diagGui,diagLabel
if pg then pcall(function() local old=pg:FindFirstChild("RAVYN_MODULAR_BOOT"); if old then old:Destroy() end; diagGui=Instance.new("ScreenGui"); diagGui.Name="RAVYN_MODULAR_BOOT"; diagGui.ResetOnSpawn=false; diagGui.IgnoreGuiInset=true; diagGui.DisplayOrder=999999; diagGui.Parent=pg; diagLabel=Instance.new("TextLabel"); diagLabel.Size=UDim2.fromOffset(720,56); diagLabel.Position=UDim2.new(.5,-360,0,16); diagLabel.BackgroundColor3=Color3.fromRGB(14,14,17); diagLabel.BackgroundTransparency=.05; diagLabel.TextColor3=Color3.fromRGB(245,205,60); diagLabel.Font=Enum.Font.Code; diagLabel.TextSize=14; diagLabel.TextWrapped=true; diagLabel.Parent=diagGui end) end
local function diag(t,bad) print(t); if diagLabel then diagLabel.Text=t; diagLabel.TextColor3=bad and Color3.fromRGB(255,90,90) or Color3.fromRGB(245,205,60) end end
local function runChunk(name,source) diag("RAVYN · compiling "..name,false); local fn,err=loadstring(source,"=RAVYN/"..name); if not fn then diag("RAVYN "..name.." COMPILE ERROR · "..tostring(err),true); return false end; local ok,res=pcall(fn); if not ok then diag("RAVYN "..name.." RUNTIME ERROR · "..tostring(res),true); return false end; diag("RAVYN · "..name.." PASS",false); return true,res end
do local ok=runChunk("Core.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
-- RAVYN Automation Lab V2
-- Self-contained executor build. Diagnostic adapter is READ-ONLY.
-- Unknown Slayers 2 integration points intentionally remain UNRESOLVED_GAME_BINDING.

local Modules = {}

-- Util
local Util = {}
function Util.isArray(t)
    if type(t) ~= "table" then return false end
    local n = 0
    for k, _ in pairs(t) do
        if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then return false end
        n = math.max(n, k)
    end
    for i = 1, n do if t[i] == nil then return false end end
    return true
end
function Util.deepCopy(v, seen)
    if type(v) ~= "table" then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end
    local out = {}; seen[v] = out
    for k, x in pairs(v) do out[Util.deepCopy(k, seen)] = Util.deepCopy(x, seen) end
    return out
end
function Util.deepMerge(target, updates)
    target = Util.deepCopy(target or {})
    for k, v in pairs(updates or {}) do
        local current = target[k]
        if type(v) == "table" and type(current) == "table" and not Util.isArray(v) and not Util.isArray(current) then
            target[k] = Util.deepMerge(current, v)
        else
            target[k] = Util.deepCopy(v)
        end
    end
    return target
end
function Util.contains(list, value)
    for _, v in ipairs(list or {}) do if v == value then return true end end
    return false
end
function Util.clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
function Util.now() return os.clock() end
function Util.safeCall(fn, ...)
    local args = table.pack(...)
    local ok, result = pcall(function() return fn(table.unpack(args, 1, args.n)) end)
    if ok then return {ok=true, value=result} end
    return {ok=false, code="LUA_ERROR", message=tostring(result), retryable=false, metadata={}}
end
function Util.path(instance)
    local parts = {}
    local cur = instance
    while cur and cur ~= game do
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
    end
    return "game." .. table.concat(parts, ".")
end
Modules.Util = Util

-- Logger
local Logger = {}; Logger.__index = Logger
function Logger.new(maxEntries)
    return setmetatable({maxEntries=maxEntries or 300, entries={}}, Logger)
end
function Logger:log(level, message, metadata)
    table.insert(self.entries, {time=os.clock(), level=level, message=tostring(message), metadata=metadata or {}})
    while #self.entries > self.maxEntries do table.remove(self.entries, 1) end
end
function Logger:clear() table.clear(self.entries) end
function Logger:getEntries() return Util.deepCopy(self.entries) end
Modules.Logger = Logger

-- Config
local Config = {}
Config.Default = {
    Runtime = {TickInterval=0.25, MaxActionsPerMinute=24, MaxConsecutiveErrors=4},
    Safety = {MinHealthPercent=35, PotionBelowPercent=45, DungeonMinHealthPercent=30},
    Targeting = {StickinessBonus=18, DistanceWeight=0.15, HealthWeight=0.10, BossBonus=25},
    Skills = {DamageWeight=1.0, CooldownWeight=0.2, PriorityWeight=10, LowHealthDefensiveBonus=30},
    Dungeon = {
        Blacklist={"Iron Discipline", "Grounded", "Bare Hands"},
        Weights={ ["Shared Points"]=35, ["Lucky Draw"]=30, ["Vampiric"]=26, ["Streak"]=22, ["Fortune"]=18 }
    },
    Maintenance = {Enabled=true, EveryActions=5},
    Logging = {MaxEntries=300},
    Diagnostic = {Enabled=true, Verbose=true, ScanInterval=3, MaxDepth=5, IncludeRemoteInventory=true, IncludePlayerState=true, IncludeCharacterState=true, IncludeGuiState=true, IncludeWorkspaceCandidates=true},
    UI = {Enabled=true, RememberSettings=true, HideKey="RightControl", CompactSidebar=false}
}
function Config.validate(c)
    local errors = {}
    local function num(path, v, minv)
        if type(v) ~= "number" or (minv and v < minv) then table.insert(errors, path) end
    end
    num("Runtime.TickInterval", c.Runtime and c.Runtime.TickInterval, 0.01)
    num("Runtime.MaxActionsPerMinute", c.Runtime and c.Runtime.MaxActionsPerMinute, 1)
    num("Safety.MinHealthPercent", c.Safety and c.Safety.MinHealthPercent, 0)
    if not (c.Dungeon and type(c.Dungeon.Blacklist)=="table" and type(c.Dungeon.Weights)=="table") then table.insert(errors, "Dungeon") end
    return #errors == 0, errors
end
function Config.new(overrides)
    local c = Util.deepMerge(Config.Default, overrides or {})
    local ok, errors = Config.validate(c)
    if not ok then return nil, {ok=false, code="INVALID_CONFIG", message=table.concat(errors, ", "), retryable=false, metadata={errors=errors}} end
    return c
end
Modules.Config = Config

-- FSM
local FSM = {}; FSM.__index = FSM
local transitions = {
    STOPPED={STARTING=true, DESTROYED=true}, STARTING={RUNNING=true, STOPPED=true}, RUNNING={PAUSED=true, STOPPING=true},
    PAUSED={RUNNING=true, STOPPING=true}, STOPPING={STOPPED=true}, DESTROYED={}
}
function FSM.new(initial) return setmetatable({state=initial or "STOPPED", history={}}, FSM) end
function FSM:transition(nextState, reason)
    if not (transitions[self.state] and transitions[self.state][nextState]) then
        return {ok=false, code="INVALID_TRANSITION", message=self.state.." -> "..tostring(nextState), retryable=false, metadata={from=self.state,to=nextState}}
    end
    table.insert(self.history, {from=self.state,to=nextState,reason=reason}); self.state=nextState
    return {ok=true, code="OK", message="transitioned", retryable=false, metadata={state=nextState}}
end
Modules.FSM = FSM

-- Scheduler
local Scheduler = {}; Scheduler.__index = Scheduler
function Scheduler.new(clock)
    return setmetatable({clock=clock or Util.now, queue={}, running={}, seq=0}, Scheduler)
end
function Scheduler:schedule(id, priority, fn, opts)
    opts = opts or {}
    if self.running[id] or self.queue[id] then return {ok=false, code="DUPLICATE_TASK", message=id, retryable=false, metadata={id=id}} end
    self.seq += 1
    self.queue[id] = {id=id, priority=priority or 0, fn=fn, timeout=opts.timeout, created=self.clock(), seq=self.seq, cancelled=false}
    return {ok=true, code="OK", message="scheduled", retryable=false, metadata={id=id}}
end
function Scheduler:cancel(id)
    local taskItem = self.queue[id] or self.running[id]
    if not taskItem then return {ok=false, code="NOT_FOUND", message=id, retryable=false, metadata={id=id}} end
    taskItem.cancelled=true; self.queue[id]=nil
    return {ok=true, code="OK", message="cancelled", retryable=false, metadata={id=id}}
end
function Scheduler:popNext()
    local best
    for _, t in pairs(self.queue) do
        if not best or t.priority > best.priority or (t.priority==best.priority and t.seq < best.seq) then best=t end
    end
    if not best then return nil end
    self.queue[best.id]=nil
    if best.timeout and (self.clock()-best.created)>=best.timeout then
        return {id=best.id, timedOut=true, task=best}
    end
    self.running[best.id]=best
    return {id=best.id, task=best}
end
function Scheduler:complete(id) self.running[id]=nil end
function Scheduler:size() local n=0; for _ in pairs(self.queue) do n+=1 end; return n end
function Scheduler:clear() table.clear(self.queue); table.clear(self.running) end
Modules.Scheduler = Scheduler

-- RateLimiter
local RateLimiter={}; RateLimiter.__index=RateLimiter
function RateLimiter.new(limit, window, clock) return setmetatable({limit=limit,window=window or 60,clock=clock or Util.now,times={}},RateLimiter) end
function RateLimiter:allow()
    local now=self.clock(); local keep={}
    for _,t in ipairs(self.times) do if now-t < self.window then table.insert(keep,t) end end
    self.times=keep
    if #self.times>=self.limit then return false end
    table.insert(self.times,now); return true
end
Modules.RateLimiter=RateLimiter

-- Scorers
local TargetScorer={}
function TargetScorer.score(target, ctx, cfg)
    local s=(target.baseScore or 0)
    s -= (target.distance or 0)*(cfg.DistanceWeight or 0)
    s += (100-(target.healthPercent or 100))*(cfg.HealthWeight or 0)
    if target.isBoss then s += cfg.BossBonus or 0 end
    if ctx.currentTargetId and target.id==ctx.currentTargetId then s += cfg.StickinessBonus or 0 end
    return s
end
function TargetScorer.best(targets, ctx, cfg)
    local best,bscore=nil,-math.huge
    for _,t in ipairs(targets or {}) do local s=TargetScorer.score(t,ctx or {},cfg or {}); if s>bscore then best,bscore=t,s end end
    return best,bscore
end
Modules.TargetScorer=TargetScorer

local SkillEngine={}
function SkillEngine.score(skill, ctx, cfg)
    if skill.available==false then return -math.huge end
    local s=(skill.priority or 0)*(cfg.PriorityWeight or 0)+(skill.damage or 0)*(cfg.DamageWeight or 0)-(skill.cooldown or 0)*(cfg.CooldownWeight or 0)
    if (ctx.healthPercent or 100)<35 and skill.defensive then s += cfg.LowHealthDefensiveBonus or 0 end
    return s
end
function SkillEngine.best(skills, ctx, cfg)
    local best,bscore=nil,-math.huge
    for _,s in ipairs(skills or {}) do local x=SkillEngine.score(s,ctx or {},cfg or {}); if x>bscore then best,bscore=s,x end end
    return best,bscore
end
Modules.SkillEngine=SkillEngine

local CardScorer={}
function CardScorer.score(card, cfg, snapshot)
    if Util.contains(cfg.Blacklist, card.name) then return -math.huge, "BLACKLISTED" end
    local score=(cfg.Weights[card.name] or 0)+(card.rewardMultiplier or 1)*8-(card.damageTakenMultiplier or 1)*7
    if (snapshot.healthPercent or 100)<50 then score += (card.healing or 0)*20-(card.healthCost or 0)*25 end
    if card.disablesSkills then score-=60 end
    if card.disablesMovement then score-=35 end
    return score,"SCORED"
end
function CardScorer.best(cards,cfg,snapshot)
    local best,bscore=nil,-math.huge
    for _,c in ipairs(cards or {}) do local s=CardScorer.score(c,cfg,snapshot or {}); if s>bscore then best,bscore=c,s end end
    return best,bscore
end
Modules.CardScorer=CardScorer

local SafetyController={}
function SafetyController.evaluate(snapshot,cfg)
    if snapshot.dead then return {kind="Recover",reason="Character died"} end
    local hp=Util.clamp(snapshot.healthPercent or 100,0,100)
    if hp<=cfg.MinHealthPercent then
        if (snapshot.potions or 0)>0 then return {kind="Potion",reason="Low-health safety override"} end
        return {kind="Rest",reason="Low-health safety override"}
    end
    return nil
end
Modules.SafetyController=SafetyController

local MaintenanceController={}
function MaintenanceController.shouldRun(actions,cfg)
    return cfg.Enabled==true and actions>0 and cfg.EveryActions>0 and actions%cfg.EveryActions==0
end
Modules.MaintenanceController=MaintenanceController

local ComboEngine={}; ComboEngine.__index=ComboEngine
function ComboEngine.new() return setmetatable({active=nil},ComboEngine) end
function ComboEngine:start(id,steps) self.active={id=id,steps=steps,index=1,cancelled=false}; return {ok=true,code="OK",message="combo started",retryable=false,metadata={id=id}} end
function ComboEngine:cancel(reason)
    if not self.active then return {ok=false,code="NO_COMBO",message="no active combo",retryable=false,metadata={}} end
    self.active.cancelled=true; self.active.cancelReason=reason; self.active=nil
    return {ok=true,code="OK",message="combo cancelled",retryable=false,metadata={reason=reason}}
end
Modules.ComboEngine=ComboEngine

-- DemoAdapter
local DemoAdapter={}; DemoAdapter.__index=DemoAdapter
function DemoAdapter.new()
    return setmetatable({state={healthPercent=100,potions=2,targets={{id="MobA",distance=15,healthPercent=100,baseScore=10}},skills={{id="Slash",priority=2,damage=20,cooldown=3,available=true}},dungeon={cards={{id=1,name="Vampiric",healing=1},{id=2,name="Grounded"}}}},failNext=nil},DemoAdapter)
end
function DemoAdapter:snapshot() return Util.deepCopy(self.state) end
function DemoAdapter:perform(action)
    if self.failNext then local e=self.failNext; self.failNext=nil; return e end
    return {ok=true,code="OK",message="demo action",retryable=false,metadata={action=action}}
end
Modules.DemoAdapter=DemoAdapter

-- Slayers2DiagnosticAdapter (READ-ONLY)
local DiagnosticAdapter={}; DiagnosticAdapter.__index=DiagnosticAdapter
local keywords={quest="QUEST",mission="QUEST",mob="COMBAT",enemy="COMBAT",boss="COMBAT",npc="QUEST",dungeon="DUNGEON",card="DUNGEON",skill="COMBAT",ability="COMBAT",breathing="COMBAT",clan="PLAYER",chest="WORLD",inventory="PLAYER",level="STATS",xp="STATS",exp="STATS",currency="STATS",money="STATS"}
local function classify(name)
    local lower=string.lower(name or ""); local score=0; local category="OTHER"
    for key,cat in pairs(keywords) do if string.find(lower,key,1,true) then score+=1; category=cat end end
    return category, math.min(1,score*0.35)
end
local function safeAttrs(inst) local ok,res=pcall(function() return inst:GetAttributes() end); return ok and res or {} end
function DiagnosticAdapter.new(config,logger) return setmetatable({config=config,logger=logger,lastSnapshot=nil,status="READY",binding="UNRESOLVED_GAME_BINDING"},DiagnosticAdapter) end
function DiagnosticAdapter:perform(action)
    return {ok=false,code="UNRESOLVED_GAME_BINDING",message="Diagnostic adapter is read-only",retryable=false,metadata={action=action}}
end
function DiagnosticAdapter:_candidate(inst)
    local cat,score=classify(inst.Name)
    if score<=0 then return nil end
    local item={name=inst.Name,class=inst.ClassName,path=Util.path(inst),category=cat,confidence=score,attributes=safeAttrs(inst)}
    if inst:IsA("ValueBase") then local ok,v=pcall(function() return inst.Value end); if ok then item.value=v end end
    return item
end
function DiagnosticAdapter:_scanRoot(root,maxItems)
    local out={}; if not root then return out end
    local ok,desc=pcall(function() return root:GetDescendants() end); if not ok then return out end
    for _,inst in ipairs(desc) do
        local c=self:_candidate(inst); if c then table.insert(out,c); if #out>=maxItems then break end end
    end
    return out
end
function DiagnosticAdapter:_remotes(root,maxItems)
    local out={}; if not root then return out end
    local ok,desc=pcall(function() return root:GetDescendants() end); if not ok then return out end
    for _,inst in ipairs(desc) do
        if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
            local cat,score=classify(inst.Name)
            table.insert(out,{name=inst.Name,class=inst.ClassName,path=Util.path(inst),parent=inst.Parent and inst.Parent.Name or "",category=cat,confidence=score})
            if #out>=maxItems then break end
        end
    end
    return out
end
function DiagnosticAdapter:createSnapshot()
    local Players=game:GetService("Players"); local ReplicatedStorage=game:GetService("ReplicatedStorage"); local Workspace=game:GetService("Workspace")
    local player=Players.LocalPlayer; local character=player and player.Character; local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    local snap={runtime={placeId=game.PlaceId,gameId=game.GameId,binding=self.binding},player={},character={},stats={},remotes={},questCandidates={},combatCandidates={},dungeonCandidates={},guiCandidates={},workspaceCandidates={},adapterStatus=self.status}
    if player then snap.player={name=player.Name,userId=player.UserId,attributes=safeAttrs(player)} end
    if character then snap.character={path=Util.path(character),attributes=safeAttrs(character),health=humanoid and humanoid.Health or nil,maxHealth=humanoid and humanoid.MaxHealth or nil} end
    snap.remotes=self:_remotes(ReplicatedStorage,100)
    local world=self:_scanRoot(Workspace,120); snap.workspaceCandidates=world
    for _,c in ipairs(world) do if c.category=="QUEST" then table.insert(snap.questCandidates,c) elseif c.category=="COMBAT" then table.insert(snap.combatCandidates,c) elseif c.category=="DUNGEON" then table.insert(snap.dungeonCandidates,c) end end
    local gui=player and player:FindFirstChildOfClass("PlayerGui"); snap.guiCandidates=self:_scanRoot(gui,100)
    if player then
        for _,c in ipairs(self:_scanRoot(player,80)) do if c.category=="STATS" or c.category=="PLAYER" then table.insert(snap.stats,c) end end
    end
    self.lastSnapshot=snap; return snap
end
function DiagnosticAdapter:getReport()
    local s=self.lastSnapshot or self:createSnapshot()
    local lines={"========== RAVYN DISCOVERY REPORT ==========","","GAME","PlaceId: "..tostring(s.runtime.placeId),"GameId: "..tostring(s.runtime.gameId),"Binding: "..tostring(s.runtime.binding),"","PLAYER","Name: "..tostring(s.player.name),"UserId: "..tostring(s.player.userId),"","CHARACTER","Path: "..tostring(s.character.path),"Health: "..tostring(s.character.health).." / "..tostring(s.character.maxHealth),"","STATS"}
    local function addList(list,maxn) for i=1,math.min(#list,maxn or 20) do local c=list[i]; table.insert(lines,string.format("- %s | %s | %s",tostring(c.name),tostring(c.class),tostring(c.path))) end end
    addList(s.stats,20); table.insert(lines,""); table.insert(lines,"REMOTES"); addList(s.remotes,30)
    table.insert(lines,""); table.insert(lines,"QUEST SYSTEM CANDIDATES"); addList(s.questCandidates,25)
    table.insert(lines,""); table.insert(lines,"COMBAT CANDIDATES"); addList(s.combatCandidates,25)
    table.insert(lines,""); table.insert(lines,"DUNGEON CANDIDATES"); addList(s.dungeonCandidates,25)
    table.insert(lines,""); table.insert(lines,"GUI CANDIDATES"); addList(s.guiCandidates,25)
    table.insert(lines,""); table.insert(lines,"============================================")
    return table.concat(lines,"\n")
end
function DiagnosticAdapter:snapshot() return self:createSnapshot() end
Modules.Slayers2DiagnosticAdapter=DiagnosticAdapter


CTX["Modules"]=Modules
CTX["Util"]=Util
CTX["Logger"]=Logger
CTX["Config"]=Config
CTX["FSM"]=FSM
CTX["transitions"]=transitions
CTX["Scheduler"]=Scheduler
CTX["RateLimiter"]=RateLimiter
CTX["TargetScorer"]=TargetScorer
CTX["SkillEngine"]=SkillEngine
CTX["CardScorer"]=CardScorer
CTX["SafetyController"]=SafetyController
CTX["MaintenanceController"]=MaintenanceController
CTX["ComboEngine"]=ComboEngine
CTX["DemoAdapter"]=DemoAdapter
CTX["DiagnosticAdapter"]=DiagnosticAdapter
CTX["keywords"]=keywords
CTX["classify"]=classify
CTX["safeAttrs"]=safeAttrs
return true]==========]); if not ok then return end end
do local ok=runChunk("Features.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Modules=CTX["Modules"]
local Util=CTX["Util"]
local Config=CTX["Config"]
local TargetScorer=CTX["TargetScorer"]
local SkillEngine=CTX["SkillEngine"]
local CardScorer=CTX["CardScorer"]
-- Phase 7: normalized state contracts, never inferred from diagnostic candidates.
local FeaturePack = {}
local function result(ok, code, value)
    return {ok=ok, code=code or (ok and "OK" or "BLOCKED"), value=value, message=code or "OK", retryable=false, metadata={}}
end
local function finite(n) return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
local function get(t,path)
    for p in string.gmatch(path,"[^%.]+") do if type(t)~="table" then return nil end; t=t[p] end
    return t
end
local function put(t,path,value)
    local parts={}; for p in string.gmatch(path,"[^%.]+") do table.insert(parts,p) end
    for i=1,#parts-1 do t=t[parts[i]] end
    t[parts[#parts]]=value
end
local function pos(p) return type(p)=="table" and finite(p.x) and finite(p.y) and finite(p.z) end
local function distance(a,b)
    if not pos(a) or not pos(b) then return nil end
    return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function farmDefaults(radius)
    return {Enabled=false,MaxDistance=radius,TargetRadius=radius,TargetName="Any",Position="Behind",Distance=6}
end
Config.Default.Farm={NormalMobs=farmDefaults(250),Boss=farmDefaults(500),FrozenYeti=farmDefaults(500)}
Config.Default.Quest={Enabled=false,AutoLevel=true,Repeat=true,Highlight=false,HighlightColor="212,175,55",HighlightTransparency=0.45}
Config.Default.Loot={Chest=false,Drop=false,Soul=false,MaxDistance=80,Cooldown=2,Whitelist={},Blacklist={},RareFirst=true}
Config.Default.Combat={AutoAttack=true,AutoAbilities=true,AutoEquip=false,Weapon="",AttackCooldown=0.5,AttackDistance=10,SkillDelay=1.35}
Config.Default.Parry={Enabled=false,ReactionWindow=0.25,Cooldown=1}
Config.Default.Movement={SpeedEnabled=false,Speed=16,MinSpeed=8,MaxSpeed=32,TravelMode="Teleport",TweenSpeed=150}
Config.Default.Teleports={NPC=false,Training=false,Schematic=false,FrozenYeti=false,SelectedNPC="",SelectedTrainer="",SelectedSchematic="",Cooldown=5}
Config.Default.Training={Enabled=false,Selected=""}
Config.Default.Muzan={Enabled=false,Repeat=true,Track=false,Notify=true,Marker=false,RoamingTrack=false}
Config.Default.Crow={Enabled=false,Repeat=true}
Config.Default.Schematic={Enabled=false,MaxDistance=80}
Config.Default.SealedChest={Enabled=false,MaxDistance=150,MinimumTier=1,PreferredTier=3,IgnoreLower=true,TierTarget=false}
Config.Default.Fishing={Enabled=false,Collect=false,Upgrade=false,MaxUpgradePrice=1000,CurrencyReserve=0,MaxUpgrades=1}
Config.Default.WorldEvents={Enabled=false,HistoryLimit=30}
Config.Default.Ouwigahara={Queue=false,Farm=false,Ready=false,Leave=false,Vote=false,SelectCard=false,LowHealthHeal=false}
Config.Default.Merchant={Enabled=false,Track=false,Notify=true,Marker=false,Whitelist={},MaxPrice=1000,CurrencyReserve=0,MaxQuantity=1}
Config.Default.Menu={JoinOuwland=false}
Config.Default.Premium={Enabled=false}
Config.Default.Dungeon.LowHealthThreshold=35
Config.Default.Dungeon.HealPriorityBonus=20
Config.Default.Dungeon.PriorityOrder={"Shared Points","Lucky Draw","Vampiric","Streak","Fortune"}
Config.Default.Dungeon.PriorityStep=1

-- Extend validation and keep SetConfig transactional in the runtime extension.
local originalValidate=Config.validate
function Config.validate(c)
    local ok,errors=originalValidate(c)
    local function walk(value,defaults,path)
        if type(value)~=type(defaults) then table.insert(errors,path); return end
        if type(defaults)=="table" then
            if Util.isArray(defaults) then
                if not Util.isArray(value) then table.insert(errors,path); return end
                for _,v in ipairs(value) do if type(v)~="string" then table.insert(errors,path); break end end
            else for k,v in pairs(defaults) do walk(value[k],v,path.."."..k) end end
        elseif type(value)=="number" and (not finite(value) or value<0) then table.insert(errors,path) end
    end
    for _,key in ipairs({"Farm","Quest","Loot","Combat","Parry","Movement","Teleports","Training","Muzan","Crow","Schematic","SealedChest","Fishing","WorldEvents","Ouwigahara","Merchant","Premium","Menu"}) do
        walk(c[key],Config.Default[key],key)
    end
    if #errors==0 then
        if c.Movement.MinSpeed>c.Movement.MaxSpeed or c.Movement.Speed<c.Movement.MinSpeed or c.Movement.Speed>c.Movement.MaxSpeed then table.insert(errors,"Movement.Speed bounds") end
        if c.Movement.TravelMode~="Tween" and c.Movement.TravelMode~="Teleport" then table.insert(errors,"Movement.TravelMode") end
        if c.Quest.HighlightTransparency>1 then table.insert(errors,"Quest.HighlightTransparency") end
        for _,f in pairs(c.Farm) do if f.Position~="Behind" and f.Position~="Above" and f.Position~="Below" and f.Position~="Near" then table.insert(errors,"Farm.Position") end end
        for _,path in ipairs({"Merchant.MaxQuantity","Fishing.MaxUpgrades","SealedChest.MinimumTier","SealedChest.PreferredTier","WorldEvents.HistoryLimit"}) do
            if get(c,path)%1~=0 then table.insert(errors,path) end
        end
    end
    for _,path in ipairs({"Dungeon.LowHealthThreshold","Dungeon.HealPriorityBonus","Dungeon.PriorityStep"}) do if not finite(get(c,path)) or get(c,path)<0 then table.insert(errors,path) end end
    if finite(c.Dungeon.LowHealthThreshold) and c.Dungeon.LowHealthThreshold>100 then table.insert(errors,"Dungeon.LowHealthThreshold") end
    if type(c.Dungeon.PriorityOrder)~="table" or not Util.isArray(c.Dungeon.PriorityOrder) then table.insert(errors,"Dungeon.PriorityOrder") end
    if c.Runtime and (not finite(c.Runtime.TickInterval) or c.Runtime.TickInterval<0.01 or not finite(c.Runtime.MaxActionsPerMinute)) then table.insert(errors,"Runtime") end
    return #errors==0,errors
end

-- {id, display name, tab, premium, config path, state/action dependencies}
local featureDefinitions={
 {"NORMAL_MOB","Normal Mobs Farm","Farm",false,"Farm.NormalMobs.Enabled",{"MOBS","PLAYER","MOVE","ATTACK"}},
 {"BOSS","Boss Farm","Farm",false,"Farm.Boss.Enabled",{"BOSSES","PLAYER","MOVE","ATTACK"}},
 {"AUTO_QUEST","Auto Quest Farm","Quest",false,"Quest.Enabled",{"QUEST_STATE","PLAYER","QUEST_ACCEPT","MOVE","ATTACK","QUEST_COMPLETE"}},
 {"QUEST_HIGHLIGHT","Highlight Quest Objective","Quest",false,"Quest.Highlight",{"QUEST_STATE","HIGHLIGHT"}},
 {"CHEST","Auto Open Chest","Loot",false,"Loot.Chest",{"LOOT","PLAYER","OPEN_CHEST"}},
 {"DROP","Auto Collect Drop","Loot",false,"Loot.Drop",{"LOOT","PLAYER","COLLECT_DROP"}},
 {"SOUL","Auto Collect Soul","Loot",false,"Loot.Soul",{"LOOT","PLAYER","COLLECT_SOUL"}},
 {"ATTACK","Auto Attack","Combat",false,"Combat.AutoAttack",{"PLAYER","ATTACK"}},
 {"ABILITIES","Auto Abilities","Combat",false,"Combat.AutoAbilities",{"PLAYER","SKILLS","ABILITY"}},
 {"PARRY","Auto Parry","Combat",false,"Parry.Enabled",{"PLAYER","INCOMING_ATTACK","PARRY"}},
 {"EQUIP","Auto Equip Weapon","Combat",false,"Combat.AutoEquip",{"PLAYER","EQUIP"}},
 {"SPEED","Move Speed Adjustment","Config",false,"Movement.SpeedEnabled",{"PLAYER","SPEED_READ","SPEED_WRITE"}},
 {"NPC_TELEPORT","NPC Teleport","Teleport",false,"Teleports.NPC",{"PLAYER","NPCS","TELEPORT"}},
 {"TRAINING_TELEPORT","Training Teleport","Teleport",false,"Teleports.Training",{"PLAYER","TRAINERS","TELEPORT"}},
 {"TRAINING","Auto Training Minigame","Training",false,"Training.Enabled",{"TRAINING_STATE","TRAINING_INTERACT"}},
 {"JOIN_OUWLAND","Auto Join Ouwland","Premium",false,"Menu.JoinOuwland",{"MENU_STATE","JOIN_OUWLAND"}},
 {"MUZAN_QUEST","Auto Muzan Quests","Quest",false,"Muzan.Enabled",{"MUZAN_QUEST","PLAYER","QUEST_ACCEPT","MOVE","ATTACK","QUEST_COMPLETE"}},
 {"CROW_QUEST","Auto Crow Quests","Quest",false,"Crow.Enabled",{"CROW_QUEST","PLAYER","QUEST_ACCEPT","MOVE","ATTACK","QUEST_COMPLETE"}},
 {"SCHEMATIC_TELEPORT","Schematic Teleport","Teleport",false,"Teleports.Schematic",{"PLAYER","SCHEMATICS","TELEPORT"}},
 {"SCHEMATIC","Auto Collect Schematic","Loot",false,"Schematic.Enabled",{"PLAYER","SCHEMATICS","COLLECT_SCHEMATIC"}},
 {"SEALED_CHEST","Auto Farm Sealed Chests","Loot",false,"SealedChest.Enabled",{"PLAYER","SEALED_CHESTS","MOVE","OPEN_SEALED_CHEST"}},
 {"SEALED_TIER","Sealed Chest Tier Target","Loot",false,"SealedChest.TierTarget",{"SEALED_CHESTS"}},
 {"FISHING","Auto Fishing","Fishing",false,"Fishing.Enabled",{"FISHING_STATE","FISH_START","FISH_INPUT"}},
 {"FISH_COLLECT","Auto Collect Fish","Fishing",false,"Fishing.Collect",{"FISHING_STATE","COLLECT_FISH"}},
 {"ROD_UPGRADE","Auto Upgrade Rod","Fishing",false,"Fishing.Upgrade",{"ROD_STATE","ROD_UPGRADE"}},
 {"WORLD_EVENTS","World Cycle & Events Display","Events",true,"WorldEvents.Enabled",{"WORLD_EVENTS"}},
 {"MUZAN_TRACK","Notify & Track Muzan","Events",true,"Muzan.Track",{"PLAYER","MUZAN_STATE"}},
 {"ROAMING_MUZAN","Notify & Track Roaming Muzan","Events",true,"Muzan.RoamingTrack",{"PLAYER","ROAMING_MUZAN"}},
 {"MARKETER_TRACK","Notify & Track Black Marketer","Events",true,"Merchant.Track",{"PLAYER","MERCHANT_STATE"}},
 {"OUWI_QUEUE","Auto Queue Ouwigahara Normal","Ouwigahara",true,"Ouwigahara.Queue",{"MENU_STATE","QUEUE_NORMAL"}},
 {"OUWI_FARM","Auto Farm Ouwigahara","Ouwigahara",true,"Ouwigahara.Farm",{"PLAYER","DUNGEON_STATE","MOVE","ATTACK"}},
 {"READY","Auto Ready Up","Ouwigahara",true,"Ouwigahara.Ready",{"DUNGEON_STATE","READY"}},
 {"LEAVE","Auto Leave After Run","Ouwigahara",true,"Ouwigahara.Leave",{"DUNGEON_STATE","LEAVE"}},
 {"VOTE","Auto Vote Skip Wave Break","Ouwigahara",true,"Ouwigahara.Vote",{"DUNGEON_STATE","VOTE"}},
 {"CARD","Auto Select Card","Ouwigahara",true,"Ouwigahara.SelectCard",{"DUNGEON_STATE","SELECT_CARD"}},
 {"HEAL_PRIORITY","Low Health Heal Priority","Ouwigahara",true,"Ouwigahara.LowHealthHeal",{"PLAYER","DUNGEON_STATE"}},
 {"YETI_FARM","Frozen Yeti Farm","Farm",true,"Farm.FrozenYeti.Enabled",{"PLAYER","YETI_STATE","MOVE","ATTACK"}},
 {"YETI_TELEPORT","Frozen Yeti Teleport","Teleport",true,"Teleports.FrozenYeti",{"PLAYER","YETI_STATE","TELEPORT"}},
 {"MERCHANT","Auto Buy Merchant","Merchant",true,"Merchant.Enabled",{"MERCHANT_STATE","PURCHASE"}},
}
local BindingRegistry={}; BindingRegistry.__index=BindingRegistry
function BindingRegistry.new() return setmetatable({entries={},generation=0},BindingRegistry) end
-- Integration point for a separately reviewed adapter. No live bindings ship in this release.
function BindingRegistry:register(id,kind,fn,evidence)
    if (kind~="state" and kind~="action") or type(fn)~="function" or type(evidence)~="table" or evidence.reviewed~=true or type(evidence.source)~="string" or evidence.source=="" or type(evidence.semantics)~="string" or evidence.semantics=="" then return result(false,"UNVERIFIED_BINDING") end
    if self.entries[id] then return result(false,"BINDING_ALREADY_REGISTERED") end
    self.entries[id]={kind=kind,fn=fn,evidence=Util.deepCopy(evidence)}; self.generation=self.generation+1
    return result(true)
end
function BindingRegistry:has(id) return self.entries[id]~=nil end
function BindingRegistry:call(id,...)
    local b=self.entries[id]; if not b then return result(false,"UNRESOLVED_GAME_BINDING") end
    local r=Util.safeCall(b.fn,...); if not r.ok then return r end
    if b.kind=="state" then return result(true,"OK",r.value) end
    if type(r.value)~="table" or type(r.value.ok)~="boolean" then return result(false,"ACTION_RESULT_UNCERTAIN") end
    return r.value
end
local FeatureRegistry={}; FeatureRegistry.__index=FeatureRegistry
function FeatureRegistry.new(config,bindings)
    local self=setmetatable({config=config,bindings=bindings,items={},order={}},FeatureRegistry)
    for _,d in ipairs(featureDefinitions) do
        local f={id=d[1],name=d[2],category=d[3],premium=d[4],path=d[5],dependencies=Util.deepCopy(d[6]),capabilities=Util.deepCopy(d[6]),enabled=false,bindingStatus="UNRESOLVED_GAME_BINDING",liveTested=false}
        self.items[f.id]=f; table.insert(self.order,f)
    end
    self:refresh(); return self
end
function FeatureRegistry:refresh()
    for _,f in ipairs(self.order) do
        f.enabled=get(self.config,f.path)==true; f.premiumAllowed=not f.premium or self.config.Premium.Enabled
        local n=0; for _,id in ipairs(f.dependencies) do if self.bindings:has(id) then n=n+1 end end
        f.bindingStatus=n==#f.dependencies and "VERIFIED" or (n>0 and "PARTIAL" or "UNRESOLVED_GAME_BINDING")
        f.available=f.enabled and f.premiumAllowed and f.bindingStatus=="VERIFIED"
        f.status=(not f.enabled or not f.premiumAllowed) and "DISABLED" or f.bindingStatus
    end
end
function FeatureRegistry:active(id) local f=self.items[id]; return f and f.available==true end

local ActivityLock={}; ActivityLock.__index=ActivityLock
FeaturePack.Priority={EMERGENCY=140,RECOVERY=130,PARRY=120,BOSS=110,QUEST=100,NORMAL_MOB=90,LOOT=80,SOUL=75,CHEST=70,EVENT=60,TRAINING=50,FISHING=40,IDLE=0}
function ActivityLock.new() return setmetatable({owner=nil,priority=-1,token=0},ActivityLock) end
function ActivityLock:acquire(owner,priority)
    if self.owner and self.owner~=owner and priority<=self.priority then return nil end
    if self.owner~=owner then self.token=self.token+1 end
    self.owner=owner; self.priority=priority; return self.token
end
function ActivityLock:valid(owner,token) return self.owner==owner and self.token==token end
function ActivityLock:release(owner) if not owner or self.owner==owner then self.owner=nil; self.priority=-1; self.token=self.token+1 end end

local originalCardScore=CardScorer.score
function CardScorer.score(card,cfg,snapshot)
    snapshot=snapshot or {}; local score,reason=originalCardScore(card,cfg,snapshot)
    if score==-math.huge then return score,reason end
    local base=cfg.Weights[card.name] or 0; local heal=0; local orderBonus=0
    for i,name in ipairs(cfg.PriorityOrder or {}) do if name==card.name then orderBonus=(#cfg.PriorityOrder-i)*(cfg.PriorityStep or 1); break end end
    if snapshot.lowHealthHealEnabled and (snapshot.healthPercent or 100)<=(cfg.LowHealthThreshold or 35) and ((card.healing or 0)>0 or card.survival==true) then heal=cfg.HealPriorityBonus or 20 end
    local synergy=finite(card.buildSynergy) and card.buildSynergy or 0
    score=score+heal+synergy+orderBonus
    return score,string.format("%s: %+.1f base; %+.1f low-health survival; %+.1f build synergy; %+.1f order; total %.1f",card.name,base,heal,synergy,orderBonus,score)
end

local FarmController={}
function FarmController.select(targets,player,cfg,scoring,current)
    if not player or player.characterValid~=true or player.rootValid~=true or not player.characterId or player.dead==true then return nil end
    local valid={}
    for _,t in ipairs(targets or {}) do
        local d=distance(player and player.position,t.position)
        if t.id and t.alive==true and finite(t.health) and t.health>0 and d and d<=cfg.MaxDistance and d<=cfg.TargetRadius and (cfg.TargetName=="Any" or t.name==cfg.TargetName) then
            local x=Util.deepCopy(t); x.distance=d; table.insert(valid,x)
        end
    end
    return TargetScorer.best(valid,{currentTargetId=current},scoring)
end
local QuestController={}
function QuestController.phase(q,cfg,player)
    if not q or not q.id then return "WAIT" end
    if q.state=="AVAILABLE" and (not cfg.AutoLevel or (finite(q.minLevel) and finite(player and player.level) and player.level>=q.minLevel)) then return "ACCEPT" end
    if q.state=="ACTIVE" and q.objective then return "OBJECTIVE" end
    if q.state=="COMPLETE" and q.completionConfirmed==true then return "COMPLETE" end
    return "WAIT"
end
local LootController={}
function LootController.select(items,player,cfg,kind,attempts)
    local valid={}
    for _,v in ipairs(items or {}) do
        local d=distance(player and player.position,v.position)
        if v.id and v.kind==kind and v.interactable==true and v.collected~=true and d and d<=cfg.MaxDistance and not attempts[kind..":"..tostring(v.id)] and not Util.contains(cfg.Blacklist,v.name) and (#(cfg.Whitelist or {})==0 or Util.contains(cfg.Whitelist,v.name)) then
            local x=Util.deepCopy(v); x.distance=d; table.insert(valid,x)
        end
    end
    table.sort(valid,function(a,b) if cfg.RareFirst and (a.rarity or 0)~=(b.rarity or 0) then return (a.rarity or 0)>(b.rarity or 0) end; if a.distance==b.distance then return tostring(a.id)<tostring(b.id) end; return a.distance<b.distance end)
    return valid[1]
end
local CombatController={}
function CombatController.plan(target,s,cfg,combo,now,lastAttack,lastSkills,abilityEnabled,attackEnabled)
    if not target or target.alive~=true or not finite(target.health) or target.health<=0 or not s.player or s.player.dead or not finite(s.player.health) or s.player.health<=0 then return nil end
    if not s.player.characterValid or not s.player.rootValid or not s.player.characterId then return nil end
    local d=distance(s.player.position,target.position); if not d then return nil end
    if abilityEnabled and not combo.active then
        local valid={}
        for _,skill in ipairs(s.skills or {}) do
            if skill.id and skill.available==true and finite(skill.readyAt) and now>=skill.readyAt and finite(skill.range) and d<=skill.range and finite(skill.cost) and finite(s.player.resource) and s.player.resource>=skill.cost and now-(lastSkills[skill.id] or -math.huge)>=math.max(skill.cooldown or 0,0.25) then table.insert(valid,skill) end
        end
        local best=SkillEngine.best(valid,{healthPercent=s.player.healthPercent},cfg.Skills)
        if best then return {binding="ABILITY",key="ability:"..tostring(best.id),payload={targetId=target.id,skillId=best.id},cooldown=math.max(best.cooldown or 0,0.25),skillId=best.id} end
    end
    if attackEnabled and d<=cfg.Combat.AttackDistance and now-lastAttack>=cfg.Combat.AttackCooldown then return {binding="ATTACK",payload={targetId=target.id},key="attack",cooldown=cfg.Combat.AttackCooldown} end
    return nil
end
local ParryController={}
function ParryController.shouldParry(a,cfg,now,last)
    return a and a.id and a.parryable==true and a.incoming==true and finite(a.impactAt) and a.impactAt>=now and a.impactAt-now<=cfg.ReactionWindow and now-last>=cfg.Cooldown
end
local SealedChestController={}
function SealedChestController.select(items,player,cfg,attempts)
    local valid={}
    for _,item in ipairs(items or {}) do
        if finite(item.tier) and (not cfg.TierTarget or not cfg.IgnoreLower or item.tier>=cfg.MinimumTier) then local x=Util.deepCopy(item); x.kind="sealed"; x.rarity=cfg.TierTarget and (item.tier==cfg.PreferredTier and 1000 or item.tier) or 0; table.insert(valid,x) end
    end
    return LootController.select(valid,player,{MaxDistance=cfg.MaxDistance,RareFirst=true},"sealed",attempts)
end
local FishingController={}
function FishingController.nextAction(f)
    if not f or not f.sessionId then return nil end
    if f.state=="IDLE" and f.canStart==true then return "FISH_START",tostring(f.sessionId)..":start" end
    if f.state=="TIMING" and f.windowOpen==true and f.inputToken then return "FISH_INPUT",tostring(f.sessionId)..":"..tostring(f.inputToken) end
    if f.state=="CAUGHT" and f.catchId and f.collectible==true then return "COLLECT_FISH",tostring(f.catchId) end
    return nil
end
local MerchantController={}; MerchantController.__index=MerchantController
function MerchantController.new() return setmetatable({pending=nil,blocked=false,purchased=0,lastReason=nil},MerchantController) end
function MerchantController:canBuy(m,item,cfg)
    if self.blocked then return false,"PURCHASE_RESULT_UNCERTAIN" end
    if self.pending then return false,"PURCHASE_PENDING" end
    if not m or m.available~=true or not m.id or not item or not item.id or item.available~=true or not Util.contains(cfg.Whitelist,item.name) then return false,"ITEM_NOT_ALLOWED" end
    if not finite(item.price) or item.price<0 or not finite(m.currency) then return false,"UNKNOWN_PRICE_OR_CURRENCY" end
    if item.price>cfg.MaxPrice then return false,"MAX_PRICE" end
    if m.currency-item.price<cfg.CurrencyReserve then return false,"CURRENCY_RESERVE" end
    if self.purchased>=cfg.MaxQuantity then return false,"QUANTITY_LIMIT" end
    if not m.observationId then return false,"MISSING_OBSERVATION" end
    return true
end
function MerchantController:begin(m,item,cfg)
    local ok,why=self:canBuy(m,item,cfg); if not ok then return result(false,why) end
    self.pending={merchantId=m.id,itemId=item.id,price=item.price,quantity=1,observationId=m.observationId}; return result(true,"OK",self.pending)
end
function MerchantController:finish(r)
    if not self.pending then return result(false,"NO_PURCHASE_PENDING") end
    if r and r.ok==true and r.confirmed==true and r.itemId==self.pending.itemId and r.quantity==1 then self.purchased=self.purchased+1; self.pending=nil; return result(true) end
    self.blocked=true; self.lastReason="PURCHASE_RESULT_UNCERTAIN"; return result(false,self.lastReason)
end
local OuwigaharaController={}
function OuwigaharaController.action(d,cfg)
    if not d or not d.runId then return nil end
    if cfg.Leave and d.state=="COMPLETED" and d.completionConfirmed then return "LEAVE",tostring(d.runId)..":leave" end
    if cfg.Ready and d.state=="READY" and d.ready~=true then return "READY",tostring(d.runId)..":ready" end
    if cfg.Vote and d.state=="BREAK" and d.voteOpen==true and d.voteId then return "VOTE",tostring(d.runId)..":vote:"..tostring(d.voteId) end
    return nil
end
local NotificationController={}; NotificationController.__index=NotificationController
function NotificationController.new() return setmetatable({items={},seen={}},NotificationController) end
function NotificationController:emit(key,message,now)
    if self.seen[key] then return false end
    self.seen[key]=true; table.insert(self.items,{message=message,time=now})
    if #self.items>50 then table.remove(self.items,1) end
    return true
end
function NotificationController:clear() self.items={}; self.seen={} end

FeaturePack.get=get; FeaturePack.put=put; FeaturePack.result=result; FeaturePack.distance=distance; FeaturePack.finite=finite
FeaturePack.definitions=featureDefinitions
Modules.FeaturePack=FeaturePack; Modules.BindingRegistry=BindingRegistry; Modules.FeatureRegistry=FeatureRegistry
Modules.ActivityLock=ActivityLock; Modules.MovementLock=ActivityLock
Modules.FarmController=FarmController; Modules.QuestController=QuestController; Modules.LootController=LootController
Modules.CombatController=CombatController; Modules.ParryController=ParryController; Modules.SealedChestController=SealedChestController
Modules.FishingController=FishingController; Modules.MerchantController=MerchantController
Modules.OuwigaharaController=OuwigaharaController; Modules.NotificationController=NotificationController

CTX["FeaturePack"]=FeaturePack
CTX["result"]=result
CTX["finite"]=finite
CTX["get"]=get
CTX["put"]=put
CTX["pos"]=pos
CTX["distance"]=distance
CTX["farmDefaults"]=farmDefaults
CTX["originalValidate"]=originalValidate
CTX["featureDefinitions"]=featureDefinitions
CTX["BindingRegistry"]=BindingRegistry
CTX["FeatureRegistry"]=FeatureRegistry
CTX["ActivityLock"]=ActivityLock
CTX["originalCardScore"]=originalCardScore
CTX["FarmController"]=FarmController
CTX["QuestController"]=QuestController
CTX["LootController"]=LootController
CTX["CombatController"]=CombatController
CTX["ParryController"]=ParryController
CTX["SealedChestController"]=SealedChestController
CTX["FishingController"]=FishingController
CTX["MerchantController"]=MerchantController
CTX["OuwigaharaController"]=OuwigaharaController
CTX["NotificationController"]=NotificationController
return true]==========]); if not ok then return end end
do local ok=runChunk("Controllers.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Modules=CTX["Modules"]
local Util=CTX["Util"]
local Logger=CTX["Logger"]
local Config=CTX["Config"]
local Scheduler=CTX["Scheduler"]
local RateLimiter=CTX["RateLimiter"]
local CardScorer=CTX["CardScorer"]
local SafetyController=CTX["SafetyController"]
local FeaturePack=CTX["FeaturePack"]
local result=CTX["result"]
local finite=CTX["finite"]
local put=CTX["put"]
local pos=CTX["pos"]
local distance=CTX["distance"]
local FeatureRegistry=CTX["FeatureRegistry"]
local ActivityLock=CTX["ActivityLock"]
local FarmController=CTX["FarmController"]
local QuestController=CTX["QuestController"]
local LootController=CTX["LootController"]
local CombatController=CTX["CombatController"]
local ParryController=CTX["ParryController"]
local SealedChestController=CTX["SealedChestController"]
local FishingController=CTX["FishingController"]
local MerchantController=CTX["MerchantController"]
local OuwigaharaController=CTX["OuwigaharaController"]
local NotificationController=CTX["NotificationController"]
-- Controllers consume normalized snapshots supplied only by reviewed bindings.
local MovementController={}; MovementController.__index=MovementController
function MovementController.new(bindings,logger)
    return setmetatable({bindings=bindings,logger=logger,originals={}},MovementController)
end
function MovementController:apply(player,cfg)
    if not player or not player.characterValid or not player.rootValid or not player.characterId or player.dead then return result(false,"INVALID_CHARACTER") end
    if not finite(cfg.Speed) or cfg.Speed<cfg.MinSpeed or cfg.Speed>cfg.MaxSpeed then return result(false,"INVALID_SPEED") end
    local key=player.characterId
    if not self.originals[key] then
        local r=self.bindings:call("SPEED_READ",{characterId=key})
        if not r.ok or not finite(r.value) then return result(false,"UNKNOWN_ORIGINAL_SPEED") end
        self.originals[key]={value=r.value,applied=nil}
    end
    local original=self.originals[key]
    if original.applied==cfg.Speed then return result(true,"UNCHANGED") end
    local r=self.bindings:call("SPEED_WRITE",{characterId=key,speed=cfg.Speed})
    if r.ok then original.applied=cfg.Speed end
    return r
end
function MovementController:restore()
    local all=true
    for key,saved in pairs(self.originals) do
        local r=self.bindings:call("SPEED_WRITE",{characterId=key,speed=saved.value,restore=true})
        if r.ok then self.originals[key]=nil else all=false; self.logger:log("ERROR","SPEED_RESTORE_FAILED",{characterId=key,code=r.code}) end
    end
    return all
end
local TeleportController={}; TeleportController.__index=TeleportController
function TeleportController.new(bindings,lock,clock)
    return setmetatable({bindings=bindings,lock=lock,clock=clock or Util.now,last=-math.huge,attempts={}},TeleportController)
end
function TeleportController:execute(destination,player,cooldown,requestId)
    if not destination or not destination.id or not pos(destination.position) or destination.locationConfirmed~=true then return result(false,"INVALID_DESTINATION") end
    if not player or not player.characterValid or not player.rootValid or not player.characterId or player.dead then return result(false,"INVALID_CHARACTER") end
    if not requestId or self.attempts[requestId] then return result(false,"DUPLICATE_TELEPORT") end
    if self.clock()-self.last<cooldown then return result(false,"TELEPORT_COOLDOWN") end
    local token=self.lock:acquire("TELEPORT",FeaturePack.Priority.EVENT)
    if not token then return result(false,"MOVEMENT_LOCKED") end
    self.attempts[requestId]=true; self.last=self.clock()
    local r=self.bindings:call("TELEPORT",{destinationId=destination.id,position=destination.position,characterId=player.characterId})
    self.lock:release("TELEPORT")
    return r
end
local TrainingController={}
function TrainingController.nextAction(s)
    if not s or not s.sessionId then return nil end
    if s.state=="COMPLETE" then return "DONE" end
    if s.state=="ACTIVE" and s.windowOpen==true and s.interactionToken then return "TRAINING_INTERACT",tostring(s.sessionId)..":"..tostring(s.interactionToken) end
    return nil
end
local MenuController={}
function MenuController.nextAction(menu,join,queue)
    if not menu or menu.state~="MAIN_MENU" or not menu.sessionId or menu.queued==true or menu.joining==true then return nil end
    if queue and menu.queueAvailable==true then return "QUEUE_NORMAL",tostring(menu.sessionId)..":queue" end
    if join and menu.ouwlandAvailable==true then return "JOIN_OUWLAND",tostring(menu.sessionId)..":join" end
    return nil
end
local SchematicController={}
function SchematicController.select(items,player,cfg,attempts)
    local list={}; for _,v in ipairs(items or {}) do local x=Util.deepCopy(v); x.kind="schematic"; table.insert(list,x) end
    return LootController.select(list,player,cfg,"schematic",attempts)
end
local WorldEventController={}; WorldEventController.__index=WorldEventController
function WorldEventController.new() return setmetatable({history={},current=nil,lastKey=nil},WorldEventController) end
function WorldEventController:update(state,now,limit)
    self.current=state
    if not state then return end
    local key=tostring(state.cycle)..":"..tostring(state.eventId or state.event)
    if key~=self.lastKey then table.insert(self.history,{cycle=state.cycle,event=state.event,time=now}); self.lastKey=key end
    while #self.history>limit do table.remove(self.history,1) end
    self.countdown=finite(state.endsAt) and math.max(0,state.endsAt-now) or nil
end
local TrackerController={}; TrackerController.__index=TrackerController
function TrackerController.new(notifications) return setmetatable({notifications=notifications,states={},generations={}},TrackerController) end
function TrackerController:update(key,state,player,notify,now)
    local previous=self.states[key]
    if not state then self.states[key]=nil; return end
    local x=Util.deepCopy(state); x.distance=distance(player and player.position,x.position)
    self.states[key]=x
    if x.present==true and (not previous or previous.present~=true or previous.spawnId~=x.spawnId) then
        self.generations[key]=(self.generations[key] or 0)+1
        if notify then self.notifications:emit(key..":"..self.generations[key],key.." detected",now) end
    end
end

local Engine={}; Engine.__index=Engine
local stateKeys={PLAYER="player",MOBS="mobs",BOSSES="bosses",QUEST_STATE="quest",LOOT="loot",SKILLS="skills",INCOMING_ATTACK="incoming",NPCS="npcs",TRAINERS="trainers",TRAINING_STATE="training",MENU_STATE="menu",MUZAN_QUEST="muzanQuest",CROW_QUEST="crowQuest",SCHEMATICS="schematics",SEALED_CHESTS="sealedChests",FISHING_STATE="fishing",ROD_STATE="rod",WORLD_EVENTS="world",MUZAN_STATE="muzan",ROAMING_MUZAN="roamingMuzan",MERCHANT_STATE="merchant",DUNGEON_STATE="dungeon",YETI_STATE="yeti"}
function Engine.new(runtime,bindings,clock)
    local self=setmetatable({runtime=runtime,bindings=bindings,clock=clock or Util.now,attempts={},cooldowns={},lastSkills={},lastAttack=-math.huge,lastParry=-math.huge,questDone={},kills={},killCount=0,previousTargets={},lastDiagnostic=-math.huge,snapshot={},currentTarget=nil,lastError=nil,highlight=nil,markerKeys={},lastReasons={}},Engine)
    self.registry=FeatureRegistry.new(runtime.Config,bindings); self.lock=ActivityLock.new()
    self.movement=MovementController.new(bindings,runtime.Logger)
    self.teleport=TeleportController.new(bindings,self.lock,self.clock)
    self.notifications=NotificationController.new(); self.events=WorldEventController.new(); self.trackers=TrackerController.new(self.notifications)
    self.merchant=MerchantController.new(); self.rodMerchant=MerchantController.new()
    self.limiter=RateLimiter.new(runtime.Config.Runtime.MaxActionsPerMinute,60,self.clock)
    return self
end
function Engine:read()
    local s={}
    for binding,key in pairs(stateKeys) do
        if self.bindings:has(binding) then
            local r=self.bindings:call(binding)
            if r.ok and type(r.value)=="table" then s[key]=r.value elseif not r.ok then self:warn(binding,r.code or "STATE_READ_ERROR") end
        end
    end
    self.snapshot=s; return s
end
function Engine:warn(key,reason)
    if self.lastReasons[key]~=reason then self.runtime.Logger:log("WARN",reason,{feature=key}); self.lastReasons[key]=reason end
end
function Engine:enabled(id) return self.registry:active(id) end
function Engine:proposal(owner,priority,binding,payload,key,once,cooldown)
    return {owner=owner,priority=priority,binding=binding,payload=payload or {},key=key or binding,once=once,cooldown=cooldown or 0.5}
end
function Engine:execute(a)
    local now=self.clock()
    if a.once and self.attempts[a.key] then return result(false,"DUPLICATE_ACTION") end
    if now<(self.cooldowns[a.key] or -math.huge) then return result(false,"COOLDOWN") end
    if not self.bindings:has(a.binding) then return result(false,"UNRESOLVED_GAME_BINDING") end
    if not self.limiter:allow() then return result(false,"RATE_LIMITED") end
    self.cooldowns[a.key]=now+a.cooldown
    if a.once then self.attempts[a.key]=true end
    local r=self.bindings:call(a.binding,a.payload)
    if a.purchase then
        r=a.purchase:finish(r)
        if not r.ok then self.runtime.Logger:log("ERROR","PURCHASE_RESULT_UNCERTAIN"); self.lastError=r.code end
    end
    if r.ok then
        self.runtime.Telemetry.actionsCompleted=self.runtime.Telemetry.actionsCompleted+1
        self.runtime.Telemetry.lastAction=a.binding
        if a.binding=="ATTACK" then self.lastAttack=now end
        if a.skillId then self.lastSkills[a.skillId]=now end
        if a.binding=="PARRY" then self.lastParry=now end
        if a.onSuccess then a.onSuccess(r) end
    else
        self.runtime.Telemetry.actionsFailed=self.runtime.Telemetry.actionsFailed+1; self.lastError=r.code
        self:warn(a.key,r.code or "ACTION_FAILED")
    end
    return r
end
function Engine:combat(owner,priority,target,s)
    local cfg=self.runtime.Config
    local a=CombatController.plan(target,s,cfg,self.runtime.Combo,self.clock(),self.lastAttack,self.lastSkills,self:enabled("ABILITIES"),self:enabled("ATTACK"))
    if a then a.owner=owner; a.priority=priority; return a end
    local d=target and distance(s.player and s.player.position,target.position)
    if d and d>cfg.Combat.AttackDistance then
        local fc=owner=="BOSS" and cfg.Farm.Boss or owner=="YETI_FARM" and cfg.Farm.FrozenYeti or cfg.Farm.NormalMobs
        return self:proposal(owner,priority,"MOVE",{targetId=target.id,position=target.position,offset=fc.Distance,placement=fc.Position,characterId=s.player.characterId},"move:"..owner,false,1)
    end
    return nil
end
function Engine:quest(owner,q,cfg,s)
    if not q or not q.id or self.questDone[owner] then return nil end
    local p=QuestController.phase(q,cfg,s.player)
    local instance=tostring(q.instanceId or q.id)
    if p=="ACCEPT" then return self:proposal(owner,100,"QUEST_ACCEPT",{questId=q.id,source=owner},owner..":"..instance..":accept",true) end
    if p=="COMPLETE" then
        local a=self:proposal(owner,100,"QUEST_COMPLETE",{questId=q.id,source=owner},owner..":"..instance..":complete",true)
        a.onSuccess=function(r) if r.confirmed==true then
            self.notifications:emit(owner..instance,"Quest completed",self.clock())
            if not cfg.Repeat then self.questDone[owner]=true end
        end end
        return a
    end
    if p=="OBJECTIVE" then
        local objective=q.objective
        if objective.target and objective.target.alive then
            local t=FarmController.select({objective.target},s.player,self.runtime.Config.Farm.NormalMobs,self.runtime.Config.Targeting)
            if t then self.currentTarget=t; return self:combat(owner,100,t,s) end
        end
        if pos(objective.position) and s.player and s.player.rootValid then return self:proposal(owner,100,"MOVE",{position=objective.position,objectiveId=objective.id,characterId=s.player.characterId},owner..":move",false,1) end
    end
    return nil
end
function Engine:buy(controller,m,items,cfg,binding,owner)
    for _,item in ipairs(items or {}) do
        local ok=controller:canBuy(m,item,cfg)
        if ok then
            -- Reserve the transaction only when the winning scheduled proposal executes.
            local a=self:proposal(owner,60,binding,nil,owner..":"..tostring(m.observationId)..":"..tostring(item.id),true,2)
            a.prepare=function()
                local r=controller:begin(m,item,cfg); if not r.ok then return r end
                a.payload=r.value; a.purchase=controller; return result(true)
            end
            return a
        end
    end
    return nil
end
function Engine:collect(s)
    local cfg=self.runtime.Config; local actions={}
    local function add(a) if a then table.insert(actions,a) end end
    local safety=SafetyController.evaluate(s.player or {},cfg.Safety)
    if safety then
        local priority=safety.kind=="Recover" and 130 or 140
        self.lock:acquire(safety.kind,priority); self.currentTarget=nil
        -- Recovery/rest/potion also require explicit actions, absent in shipped adapter.
        add(self:proposal(safety.kind,priority,string.upper(safety.kind),{},"safety:"..safety.kind,false,2))
        return actions
    end
    if self:enabled("PARRY") and ParryController.shouldParry(s.incoming,cfg.Parry,self.clock(),self.lastParry) then add(self:proposal("PARRY",120,"PARRY",{attackId=s.incoming.id},"parry:"..tostring(s.incoming.id),true,cfg.Parry.Cooldown)) end
    local farmSources={{"BOSS",s.bosses,cfg.Farm.Boss,110},{"YETI_FARM",s.yeti and {s.yeti},cfg.Farm.FrozenYeti,110},{"NORMAL_MOB",s.mobs,cfg.Farm.NormalMobs,90}}
    if self:enabled("OUWI_FARM") and s.dungeon and s.dungeon.state=="RUNNING" then table.insert(farmSources,1,{"OUWI_FARM",s.dungeon.enemies,cfg.Farm.NormalMobs,110}) end
    local selected,selectedPriority=nil,-1
    for _,v in ipairs(farmSources) do if self:enabled(v[1]) then
        local t=FarmController.select(v[2],s.player,v[3],cfg.Targeting,self.currentTarget and self.currentTarget.id)
        if t then
            if v[4]>selectedPriority then selected=t; selectedPriority=v[4] end
            self.lock:acquire(v[1],v[4]); add(self:combat(v[1],v[4],t,s))
        end
    end end
    self.currentTarget=selected
    for _,q in ipairs({{"AUTO_QUEST","quest",cfg.Quest},{"MUZAN_QUEST","muzanQuest",cfg.Muzan},{"CROW_QUEST","crowQuest",cfg.Crow}}) do
        if self:enabled(q[1]) and selectedPriority<100 then
            local a=self:quest(q[1],s[q[2]],q[3],s)
            if a then self.lock:acquire(q[1],100); add(a) end
        end
    end
    for _,l in ipairs({{"DROP","drop","COLLECT_DROP",80},{"SOUL","soul","COLLECT_SOUL",75},{"CHEST","chest","OPEN_CHEST",70}}) do
        if self:enabled(l[1]) then local item=LootController.select(s.loot,s.player,cfg.Loot,l[2],self.attempts)
            if item then add(self:proposal(l[1],l[4],l[3],{id=item.id},l[2]..":"..tostring(item.id),true,cfg.Loot.Cooldown)) end
        end
    end
    if self:enabled("SCHEMATIC") then local item=SchematicController.select(s.schematics,s.player,cfg.Schematic,self.attempts); if item then add(self:proposal("SCHEMATIC",80,"COLLECT_SCHEMATIC",{id=item.id},"schematic:"..tostring(item.id),true,2)) end end
    if self:enabled("SEALED_CHEST") then local item=SealedChestController.select(s.sealedChests,s.player,cfg.SealedChest,self.attempts)
        if item then
            if item.tier>=cfg.SealedChest.PreferredTier then self.notifications:emit("sealed:"..tostring(item.id),"Rare sealed chest found",self.clock()) end
            if item.distance>cfg.Loot.MaxDistance then add(self:proposal("SEALED_CHEST",70,"MOVE",{position=item.position,characterId=s.player.characterId},"sealed:move",false,1))
            else add(self:proposal("SEALED_CHEST",70,"OPEN_SEALED_CHEST",{id=item.id},"sealed:"..tostring(item.id),true,2)) end
        end
    end
    if self:enabled("EQUIP") and s.player and s.player.characterValid and s.player.characterId and s.player.equippedWeapon~=cfg.Combat.Weapon and cfg.Combat.Weapon~="" and Util.contains(s.player.weapons,cfg.Combat.Weapon) then add(self:proposal("EQUIP",115,"EQUIP",{weapon=cfg.Combat.Weapon,characterId=s.player.characterId},"equip:"..tostring(s.player.characterId)..":"..tostring(s.player.equipmentRevision or "initial")..":"..cfg.Combat.Weapon,true,2)) end
    local menuAction,menuKey=MenuController.nextAction(s.menu,self:enabled("JOIN_OUWLAND"),self:enabled("OUWI_QUEUE"))
    if menuAction then add(self:proposal("MENU",60,menuAction,{mode="Normal",sessionId=s.menu.sessionId},menuKey,true,3)) end
    local dungeonFlags={Ready=self:enabled("READY"),Leave=self:enabled("LEAVE"),Vote=self:enabled("VOTE")}
    local dungeonAction,dungeonKey=OuwigaharaController.action(s.dungeon,dungeonFlags)
    if dungeonAction then add(self:proposal("OUWI",60,dungeonAction,{runId=s.dungeon.runId,voteId=s.dungeon.voteId},dungeonKey,true,1)) end
    if s.dungeon and s.dungeon.state=="COMPLETED" and s.dungeon.completionConfirmed then self.notifications:emit("run:"..tostring(s.dungeon.runId),"Ouwigahara run complete",self.clock()) end
    if self:enabled("CARD") and s.dungeon and s.dungeon.state=="CARD" and s.dungeon.runId and s.dungeon.choiceId then
        local context={healthPercent=s.player and s.player.healthPercent,lowHealthHealEnabled=self:enabled("HEAL_PRIORITY")}
        local best=CardScorer.best(s.dungeon.cards,cfg.Dungeon,context)
        self.cardExplanation={}
        for _,card in ipairs(s.dungeon.cards or {}) do local score,why=CardScorer.score(card,cfg.Dungeon,context); table.insert(self.cardExplanation,{name=card.name,score=score,reason=why,selected=card==best}) end
        if best then
            self.cardChoice=best.name
            local a=self:proposal("CARD",60,"SELECT_CARD",{cardId=best.id,choiceId=s.dungeon.choiceId},"card:"..tostring(s.dungeon.runId)..":"..tostring(s.dungeon.choiceId),true)
            a.onSuccess=function() for _,e in ipairs(self.cardExplanation) do self.runtime.Logger:log("INFO",(e.selected and "SELECTED " or "REJECTED ")..e.reason) end end
            add(a)
        end
    end
    if self:enabled("TRAINING") and (cfg.Training.Selected=="" or (s.training and s.training.name==cfg.Training.Selected)) then local action,key=TrainingController.nextAction(s.training)
        if action=="DONE" then put(cfg,"Training.Enabled",false)
        elseif action then add(self:proposal("TRAINING",50,action,{token=s.training.interactionToken,sessionId=s.training.sessionId},"training:"..key,true)) end
    end
    local fishingAction,fishingKey=FishingController.nextAction(s.fishing)
    if fishingAction and ((fishingAction=="COLLECT_FISH" and self:enabled("FISH_COLLECT")) or (fishingAction~="COLLECT_FISH" and self:enabled("FISHING"))) then add(self:proposal("FISHING",40,fishingAction,{sessionId=s.fishing.sessionId,catchId=s.fishing.catchId,inputToken=s.fishing.inputToken},"fish:"..fishingKey,true)) end
    if self:enabled("MERCHANT") and s.merchant then add(self:buy(self.merchant,s.merchant,s.merchant.items,cfg.Merchant,"PURCHASE","MERCHANT")) end
    if self:enabled("ROD_UPGRADE") and s.rod and s.rod.currentRod and s.rod.upgradeAvailable and s.rod.resourcesSufficient and s.rod.upgrade then
        local c={Whitelist={s.rod.upgrade.name},MaxPrice=cfg.Fishing.MaxUpgradePrice,CurrencyReserve=cfg.Fishing.CurrencyReserve,MaxQuantity=cfg.Fishing.MaxUpgrades}
        add(self:buy(self.rodMerchant,s.rod,{s.rod.upgrade},c,"ROD_UPGRADE","ROD_UPGRADE"))
    end
    return actions
end
function Engine:visuals(s)
    local cfg=self.runtime.Config; local now=self.clock()
    self.events:update(self:enabled("WORLD_EVENTS") and s.world or nil,now,cfg.WorldEvents.HistoryLimit)
    for _,t in ipairs({{"MUZAN_TRACK","Muzan",s.muzan,cfg.Muzan.Notify,cfg.Muzan.Marker},{"ROAMING_MUZAN","Roaming Muzan",s.roamingMuzan,cfg.Muzan.Notify,cfg.Muzan.Marker},{"MARKETER_TRACK","Black Marketer",s.merchant,cfg.Merchant.Notify,cfg.Merchant.Marker},{"YETI_FARM","Frozen Yeti",s.yeti,true,false}}) do
        local state=self:enabled(t[1]) and t[3] or nil
        self.trackers:update(t[2],state,s.player,t[4],now)
        local markerKey=state and t[5] and state.present==true and pos(state.position) and tostring(state.spawnId or state.id) or nil
        if self.markerKeys[t[2]]~=markerKey and self.bindings:has("MARKER") then
            local r=self.bindings:call("MARKER",{key=t[2],position=markerKey and state.position or nil,clear=markerKey==nil})
            if r.ok then self.markerKeys[t[2]]=markerKey end
        end
    end
    local objective=self:enabled("QUEST_HIGHLIGHT") and s.quest and s.quest.objective or nil
    local nextId=objective and objective.id
    if nextId~=self.highlight and self.bindings:has("HIGHLIGHT") then
        local r=self.bindings:call("HIGHLIGHT",{objectiveId=nextId,clear=nextId==nil,color=cfg.Quest.HighlightColor,transparency=cfg.Quest.HighlightTransparency})
        if r.ok then self.highlight=nextId end
    end
end
function Engine:step()
    self.registry.config=self.runtime.Config; self.registry:refresh()
    self.limiter.limit=self.runtime.Config.Runtime.MaxActionsPerMinute
    local s=self:read(); self.lock:release(); self.runtime.Scheduler:clear()
    self:visuals(s)
    if self:enabled("SPEED") then self.movement:apply(s.player,self.runtime.Config.Movement) elseif next(self.movement.originals) then self.movement:restore() end
    for _,list in ipairs({s.mobs or {},s.bosses or {},s.dungeon and s.dungeon.enemies or {}}) do
        for _,t in ipairs(list) do
            if t.id then
                local key=tostring(t.spawnId or t.id)
                if t.alive==false and t.killedByPlayer==true and self.previousTargets[key] and not self.kills[key] then self.kills[key]=true; self.killCount=self.killCount+1 end
                self.previousTargets[key]=t.alive==true
            end
        end
    end
    local proposals=self:collect(s)
    for i,a in ipairs(proposals) do self.runtime.Scheduler:schedule(a.owner..":"..i,a.priority,function() return a end) end
    while self.runtime.Scheduler:size()>0 do
        local item=self.runtime.Scheduler:popNext(); local a=item.task.fn(); self.runtime.Scheduler:complete(item.id)
        if (not self.lock.owner or self.lock.owner==a.owner or a.priority>self.lock.priority) and (not a.once or not self.attempts[a.key]) and self.clock()>=(self.cooldowns[a.key] or -math.huge) then
            local token=self.lock:acquire(a.owner,a.priority)
            if token and self.lock:valid(a.owner,token) then
                -- Avoid opening a purchase transaction when limiter will reject dispatch.
                if a.prepare then
                    if #self.limiter.times>=self.limiter.limit then
                        local keep={}; for _,t in ipairs(self.limiter.times) do if self.clock()-t<60 then table.insert(keep,t) end end; self.limiter.times=keep
                    end
                    if #self.limiter.times<self.limiter.limit then local prepared=a.prepare(); if prepared.ok then self:execute(a) end end
                else self:execute(a) end
                break
            end
        end
    end
    self.runtime.Scheduler:clear()
end
function Engine:stop()
    self.runtime.Scheduler:clear(); self.lock:release(); self.currentTarget=nil
    local restored=self.movement:restore()
    if self.highlight and self.bindings:has("HIGHLIGHT") then self.bindings:call("HIGHLIGHT",{clear=true}); self.highlight=nil end
    if self.bindings:has("MARKER") then for key in pairs(self.markerKeys) do self.bindings:call("MARKER",{key=key,clear=true}) end end
    self.markerKeys={}
    -- Attempt ledgers and uncertain transactions survive Stop/Start to prevent retries.
    return restored
end
Modules.MovementController=MovementController; Modules.TeleportController=TeleportController
Modules.TrainingController=TrainingController; Modules.MenuController=MenuController; Modules.SchematicController=SchematicController
Modules.WorldEventController=WorldEventController; Modules.TrackerController=TrackerController
Modules.MuzanController=QuestController; Modules.CrowQuestController=QuestController
Modules.DungeonEngine=OuwigaharaController; Modules.FeatureEngine=Engine

CTX["MovementController"]=MovementController
CTX["TeleportController"]=TeleportController
CTX["TrainingController"]=TrainingController
CTX["MenuController"]=MenuController
CTX["SchematicController"]=SchematicController
CTX["WorldEventController"]=WorldEventController
CTX["TrackerController"]=TrackerController
CTX["Engine"]=Engine
CTX["stateKeys"]=stateKeys
return true]==========]); if not ok then return end end
do local ok=runChunk("Runtime.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Modules=CTX["Modules"]
local Util=CTX["Util"]
local Logger=CTX["Logger"]
local Config=CTX["Config"]
local FSM=CTX["FSM"]
local Scheduler=CTX["Scheduler"]
local RateLimiter=CTX["RateLimiter"]
local SafetyController=CTX["SafetyController"]
local ComboEngine=CTX["ComboEngine"]
local DiagnosticAdapter=CTX["DiagnosticAdapter"]
local result=CTX["result"]
-- Runtime controller
local RAVYN={Version="2.0.0",Build="2026-09-26-r1",Runtime="Executor",AdapterName="Diagnostic",Status="READY"}
RAVYN._Modules=Modules
local config,configErr=Config.new({})
if not config then error(configErr.message) end
RAVYN.Config=config; RAVYN.Logger=Logger.new(config.Logging.MaxEntries); RAVYN.FSM=FSM.new("STOPPED"); RAVYN.Scheduler=Scheduler.new(); RAVYN.Combo=ComboEngine.new(); RAVYN.Telemetry={startedAt=nil,actionsCompleted=0,actionsFailed=0,lastAction=nil}
RAVYN.Adapter=DiagnosticAdapter.new(config.Diagnostic,RAVYN.Logger)
RAVYN._loopToken=0; RAVYN._destroyed=false; RAVYN._connections={}
local limiter=RateLimiter.new(config.Runtime.MaxActionsPerMinute,60)

function RAVYN:SetConfig(path,value)
    local node=self.Config; local parts={}
    for part in string.gmatch(path,"[^%.]+") do table.insert(parts,part) end
    for i=1,#parts-1 do if type(node[parts[i]])~="table" then return {ok=false,code="INVALID_PATH",message=path,retryable=false,metadata={}} end; node=node[parts[i]] end
    node[parts[#parts]]=Util.deepCopy(value); local ok,errors=Config.validate(self.Config)
    if not ok then return {ok=false,code="INVALID_CONFIG",message=table.concat(errors,", "),retryable=false,metadata={errors=errors}} end
    return {ok=true,code="OK",message="updated",retryable=false,metadata={path=path}}
end
function RAVYN:_tick()
    if self.FSM.state~="RUNNING" then return end
    local safe=Util.safeCall(function() return self.Adapter:snapshot() end)
    if not safe.ok then self.Logger:log("ERROR",safe.message); self.Telemetry.actionsFailed+=1; return end
    local snapshot=safe.value
    local override=SafetyController.evaluate(snapshot,self.Config.Safety)
    if override and limiter:allow() then
        local result=self.Adapter:perform(override)
        if result.ok then self.Telemetry.actionsCompleted+=1 else self.Telemetry.actionsFailed+=1; self.Logger:log("WARN",result.message,result.metadata) end
    end
end
function RAVYN:Start()
    if self._destroyed then return {ok=false,code="DESTROYED",message="controller destroyed",retryable=false,metadata={}} end
    if self.FSM.state=="RUNNING" or self.FSM.state=="STARTING" then return {ok=false,code="ALREADY_RUNNING",message="Start suppressed",retryable=false,metadata={}} end
    local tr=self.FSM:transition("STARTING","Start"); if not tr.ok then return tr end
    self.FSM:transition("RUNNING","Start complete"); self.Telemetry.startedAt=self.Telemetry.startedAt or os.clock(); self._loopToken+=1; local token=self._loopToken
    task.spawn(function() while token==self._loopToken and self.FSM.state~="STOPPED" and self.FSM.state~="DESTROYED" do self:_tick(); task.wait(self.Config.Runtime.TickInterval) end end)
    return {ok=true,code="OK",message="started",retryable=false,metadata={token=token}}
end
function RAVYN:Pause() if self.FSM.state~="RUNNING" then return {ok=false,code="NOT_RUNNING",message="cannot pause",retryable=false,metadata={}} end; return self.FSM:transition("PAUSED","Pause") end
function RAVYN:Resume() if self.FSM.state~="PAUSED" then return {ok=false,code="NOT_PAUSED",message="cannot resume",retryable=false,metadata={}} end; return self.FSM:transition("RUNNING","Resume") end
function RAVYN:Stop()
    if self.FSM.state=="STOPPED" then return {ok=true,code="OK",message="already stopped",retryable=false,metadata={}} end
    if self.FSM.state=="DESTROYED" then return {ok=false,code="DESTROYED",message="destroyed",retryable=false,metadata={}} end
    local tr=self.FSM:transition("STOPPING","Stop"); if not tr.ok then return tr end
    self._loopToken+=1; self.Scheduler:clear(); self.Combo.active=nil; return self.FSM:transition("STOPPED","Stop complete")
end
function RAVYN:Destroy()
    if self.FSM.state=="DESTROYED" then return {ok=true,code="OK",message="already destroyed",retryable=false,metadata={}} end
    if self.FSM.state~="STOPPED" then self:Stop() end
    self._loopToken+=1; self.Scheduler:clear(); for _,c in ipairs(self._connections) do pcall(function() c:Disconnect() end) end; table.clear(self._connections)
    if self._gui then pcall(function() self._gui:Destroy() end); self._gui=nil end
    self._destroyed=true; return self.FSM:transition("DESTROYED","Destroy")
end
function RAVYN:RunDiscovery() self.Adapter.lastSnapshot=nil; return self.Adapter:createSnapshot() end
function RAVYN:CreateDiagnosticSnapshot() return self.Adapter:createSnapshot() end
function RAVYN:PrintDiagnosticSnapshot() local r=self.Adapter:getReport(); for chunk in string.gmatch(r,"[^\n]+") do print(chunk) end; return r end
function RAVYN:GetDiagnosticReport() return self.Adapter:getReport() end
function RAVYN:ClearLogs() self.Logger:clear(); return true end


CTX["RAVYN"]=RAVYN
CTX["config"]=config
CTX["configErr"]=configErr
CTX["limiter"]=limiter
return true]==========]); if not ok then return end end
do local ok=runChunk("Integration.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Util=CTX["Util"]
local Logger=CTX["Logger"]
local Config=CTX["Config"]
local FSM=CTX["FSM"]
local Scheduler=CTX["Scheduler"]
local result=CTX["result"]
local get=CTX["get"]
local put=CTX["put"]
local pos=CTX["pos"]
local distance=CTX["distance"]
local BindingRegistry=CTX["BindingRegistry"]
local ActivityLock=CTX["ActivityLock"]
local OuwigaharaController=CTX["OuwigaharaController"]
local Engine=CTX["Engine"]
local RAVYN=CTX["RAVYN"]
local config=CTX["config"]
-- Extend the existing runtime; retain its FSM, Scheduler, Logger and lifecycle.
RAVYN.Version="3.0.0"
RAVYN.Build="2026-09-26-phase7"
RAVYN.Bindings=BindingRegistry.new()
RAVYN.Features=Engine.new(RAVYN,RAVYN.Bindings)
RAVYN.Registry=RAVYN.Features.registry
RAVYN.ActivityLock=RAVYN.Features.lock
RAVYN.MovementLock=RAVYN.Features.lock
RAVYN.DungeonEngine=OuwigaharaController
function RAVYN:SetConfig(path,value)
    if self._destroyed then return result(false,"DESTROYED") end
    if type(path)~="string" or path=="" or get(self.Config,path)==nil then return result(false,"INVALID_PATH") end
    local candidate=Util.deepCopy(self.Config)
    local good=pcall(function() put(candidate,path,Util.deepCopy(value)) end)
    if not good then return result(false,"INVALID_PATH") end
    local checked,ok,errors=pcall(Config.validate,candidate)
    if not checked or not ok then return result(false,"INVALID_CONFIG",checked and errors or {tostring(ok)}) end
    self.Config=candidate; self.Adapter.config=candidate.Diagnostic
    self.Registry.config=candidate; self.Registry:refresh()
    -- Changed behavior cannot leave stale movement ownership or saved speed behind.
    self.Scheduler:clear(); self.Features.lock:release()
    if not candidate.Movement.SpeedEnabled then self.Features.movement:restore() end
    if not candidate.Quest.Highlight and self.Features.highlight then
        self.Bindings:call("HIGHLIGHT",{clear=true}); self.Features.highlight=nil
    end
    return result(true)
end
function RAVYN:SetFeature(id,enabled)
    local f=self.Registry.items[id]; if not f then return result(false,"UNKNOWN_FEATURE") end
    if type(enabled)~="boolean" then return result(false,"INVALID_CONFIG") end
    return self:SetConfig(f.path,enabled)
end
function RAVYN:RegisterBinding(id,kind,fn,evidence)
    if self.FSM.state~="STOPPED" then return result(false,"STOP_BEFORE_BINDING_CHANGE") end
    if self._destroyed then return result(false,"DESTROYED") end
    local r=self.Bindings:register(id,kind,fn,evidence); self.Registry:refresh(); return r
end
function RAVYN:GetFeatureMatrix()
    self.Registry:refresh(); return Util.deepCopy(self.Registry.order)
end
function RAVYN:GetLocations(kind,query)
    local map={NPC="npcs",Training="trainers",Schematic="schematics",FrozenYeti="yeti"}
    if not map[kind] then return {} end
    local s=self.Features.snapshot; local list=s[map[kind]] or {}
    if kind=="FrozenYeti" then list=s.yeti and {s.yeti} or {} end
    local out={}; query=string.lower(query or "")
    for _,item in ipairs(list) do
        if item.id and pos(item.position) and string.find(string.lower(item.name or tostring(item.id)),query,1,true) then
            local x=Util.deepCopy(item); x.distance=distance(s.player and s.player.position,item.position); table.insert(out,x)
        end
    end
    table.sort(out,function(a,b) return tostring(a.name or a.id)<tostring(b.name or b.id) end)
    return out
end
function RAVYN:TeleportTo(kind,id)
    if self.FSM.state~="RUNNING" then return result(false,"START_REQUIRED") end
    local feature={NPC="NPC_TELEPORT",Training="TRAINING_TELEPORT",Schematic="SCHEMATIC_TELEPORT",FrozenYeti="YETI_TELEPORT"}
    self.Registry:refresh()
    if not feature[kind] or not self.Registry:active(feature[kind]) then return result(false,"FEATURE_UNAVAILABLE") end
    self.Features:read()
    local destination
    for _,d in ipairs(self:GetLocations(kind)) do if d.id==id then destination=d; break end end
    self._teleportRequest=(self._teleportRequest or 0)+1
    return self.Features.teleport:execute(destination,self.Features.snapshot.player,self.Config.Teleports.Cooldown,"manual:"..self._teleportRequest)
end
function RAVYN:GetDashboard()
    local e=self.Features; local s=e.snapshot; local p=s.player or {}; local q=s.quest or {}; local d=s.dungeon or {}; local t=e.currentTarget or {}
    return {
        {"Current Activity",e.lock.owner or "IDLE"},{"Current Target",t.name},{"Target Position",t.position},{"Target Distance",t.distance},
        {"Current Quest",q.name or q.id},{"Quest Progress",q.progress},{"Current Boss",t.isBoss and t.name or nil},{"Boss Distance",t.isBoss and t.distance or nil},
        {"Health",p.health},{"Level",p.level},{"XP",p.xp},{"World Event",e.events.current and e.events.current.event},
        {"Ouwigahara Wave",d.wave},{"Current Card Choice",e.cardChoice},{"Scheduler Queue",self.Scheduler:size()},
        {"Errors",self.Telemetry.actionsFailed},{"Runtime",self.Telemetry.startedAt and math.floor(os.clock()-self.Telemetry.startedAt) or 0},
        {"Confirmed Kill Count",e.killCount},{"Binding",self.Adapter.binding},{"Last Error",e.lastError},
    }
end
local basePause=RAVYN.Pause
local baseStop=RAVYN.Stop
local baseDestroy=RAVYN.Destroy
function RAVYN:Pause()
    local r=basePause(self); if r.ok then self.Features:stop(); self.Combo.active=nil end; return r
end
function RAVYN:Stop()
    local restored=self.Features:stop(); local r=baseStop(self)
    if not restored and r.ok then return result(false,"SPEED_RESTORE_FAILED") end
    return r
end
function RAVYN:Destroy()
    self.Features:stop(); self.Features.notifications:clear()
    return baseDestroy(self)
end
function RAVYN:_tick()
    if self.FSM.state~="RUNNING" then return end
    local r=Util.safeCall(function() self.Features:step() end)
    if not r.ok then
        self.Telemetry.actionsFailed=self.Telemetry.actionsFailed+1
        self.Features.lastError=r.message; self.Logger:log("ERROR",r.message)
        self:Pause()
    end
end
-- Diagnostic scans are explicit, not run repeatedly by the automation loop.
-- This avoids treating discovery candidates as normalized verified observations.

CTX["basePause"]=basePause
CTX["baseStop"]=baseStop
CTX["baseDestroy"]=baseDestroy
return true]==========]); if not ok then return end end
do local ok=runChunk("ReadAdapter.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Modules=CTX["Modules"]
local Util=CTX["Util"]
local classify=CTX["classify"]
local result=CTX["result"]
local finite=CTX["finite"]
local pos=CTX["pos"]
local distance=CTX["distance"]
local config=CTX["config"]
-- PHASE 8. Read-only adapter. No remote dispatch, movement, equip or combat.
local Slayers2ReadAdapter={}; Slayers2ReadAdapter.__index=Slayers2ReadAdapter
local function readResult(ok,code,value,evidence)
    return {ok=ok,code=code or "OK",message=code or "OK",value=value,evidence=evidence or {},retryable=false,metadata={}}
end
local function readProp(instance,key)
    local ok,value=pcall(function() return instance[key] end); if ok then return value end
    return nil
end
local function isInstance(x)
    if x==nil then return false end
    local ok,v=pcall(function() return x:IsA("Instance") end); return ok and v==true
end
local function isA(x,class)
    if not isInstance(x) then return false end
    local ok,v=pcall(function() return x:IsA(class) end); return ok and v==true
end
local function child(x,name)
    if not isInstance(x) then return nil end
    local ok,v=pcall(function() return x:FindFirstChild(name) end); if ok and isInstance(v) then return v end
    return nil
end
local function children(x)
    if not isInstance(x) then return {} end
    local ok,v=pcall(function() return x:GetChildren() end); return ok and type(v)=="table" and v or {}
end
local function pathOf(x)
    if not isInstance(x) then return "<missing>" end
    local ok,v=pcall(function() return x:GetFullName() end); return ok and ("game."..v) or "<unavailable>"
end
local function attrs(x)
    if not isInstance(x) then return {} end
    local ok,v=pcall(function() return x:GetAttributes() end); return ok and type(v)=="table" and v or {}
end
local function xyz(v)
    if v==nil then return nil end
    local ok,p=pcall(function() return {x=v.X,y=v.Y,z=v.Z} end)
    if ok and pos(p) then return p end; return nil
end
local function scalar(v)
    if type(v)=="string" then return string.sub(v,1,512) end
    if type(v)=="boolean" or (type(v)=="number" and finite(v)) then return v end
    local p=xyz(v); if p then return string.format("X=%g Y=%g Z=%g",p.x,p.y,p.z) end
    if isInstance(v) then return pathOf(v) end
    return nil
end
local function walk(root,limit,depth)
    local out={}; local queue={{node=root,depth=0}}; local head=1; local truncated=false
    while head<=#queue and #out<limit do
        local item=queue[head]; head=head+1
        if isInstance(item.node) then
            table.insert(out,item.node)
            local list=children(item.node)
            if item.depth<depth then
                for _,v in ipairs(list) do
                    if #queue>=limit then truncated=true; break end
                    table.insert(queue,{node=v,depth=item.depth+1})
                end
            elseif #list>0 then truncated=true end
        end
    end
    return out,truncated or head<=#queue
end
local function safeRead(fn)
    local ok,r=pcall(fn)
    if not ok then return readResult(false,"READ_ERROR",nil,{tostring(r)}) end
    return r
end
function Slayers2ReadAdapter.new(options)
    options=options or {}
    return setmetatable({game=options.game or game,testMode=options.testMode==true,maxNodes=options.maxNodes or 1200,maxDepth=12,lastEntities={},evidence={},clock=options.clock or os.clock},Slayers2ReadAdapter)
end
function Slayers2ReadAdapter:_service(name)
    local ok,s=pcall(function() return self.game:GetService(name) end); return ok and isInstance(s) and s or nil
end
function Slayers2ReadAdapter:_player()
    local players=self:_service("Players"); local p=players and readProp(players,"LocalPlayer")
    return isInstance(p) and p or nil
end
function Slayers2ReadAdapter:_resolve(root,parts)
    for _,name in ipairs(parts) do root=child(root,name); if not root then break end end
    return root
end
function Slayers2ReadAdapter:_gui(parts)
    return self:_resolve(child(self:_player(),"PlayerGui"),parts)
end
function Slayers2ReadAdapter:_observe(id,paths)
    -- Test mocks never produce live verification. Only actual DataModel observations do.
    local actual=not self.testMode and typeof and typeof(self.game)=="Instance" and isA(self.game,"DataModel")
    self.evidence[id]={bindingStatus=actual and "VERIFIED" or "PARTIAL",evidence=paths,lastVerified=actual and os.time() or nil,liveTested=actual==true,source=actual and "CURRENT_RUNTIME_PROPERTY_READ" or "TEST_OR_UNCONFIRMED_RUNTIME"}
end
function Slayers2ReadAdapter:getCharacter()
    return safeRead(function()
        local p=self:_player(); if not p then return readResult(false,"LOCAL_PLAYER_UNAVAILABLE") end
        local container=child(self:_service("Workspace"),"Humanoids")
        local custom=child(container,readProp(p,"Name"))
        if isA(custom,"Model") and readProp(custom,"Parent") then
            self:_observe("CHARACTER_LOOKUP",{pathOf(custom)})
            return readResult(true,"OK",custom,{pathOf(custom)})
        end
        local fallback=readProp(p,"Character")
        if isA(fallback,"Model") and readProp(fallback,"Parent") then return readResult(true,"FALLBACK_LOCALPLAYER_CHARACTER",fallback,{pathOf(fallback)}) end
        return readResult(false,"CHARACTER_UNAVAILABLE")
    end)
end
function Slayers2ReadAdapter:_entityHumanoid(entity)
    if not isA(entity,"Model") or not readProp(entity,"Parent") then return nil end
    for _,x in ipairs(children(entity)) do if isA(x,"Humanoid") then return x end end
    return nil
end
function Slayers2ReadAdapter:getHumanoid()
    return safeRead(function()
        local r=self:getCharacter(); if not r.ok then return r end
        local h=self:_entityHumanoid(r.value)
        if not h then return readResult(false,"HUMANOID_UNAVAILABLE") end
        return readResult(true,"OK",h,{pathOf(h)})
    end)
end
function Slayers2ReadAdapter:_entityRoot(entity)
    if not isA(entity,"Model") or not readProp(entity,"Parent") then return nil end
    local root=child(entity,"HumanoidRootPart")
    if isA(root,"BasePart") then return root end
    -- A valid model-owned PrimaryPart is a read fallback, never a teleport approval.
    local primary=readProp(entity,"PrimaryPart")
    if isA(primary,"BasePart") then
        local ok,inside=pcall(function() return primary:IsDescendantOf(entity) end)
        if ok and inside then return primary end
    end
    return nil
end
function Slayers2ReadAdapter:getRootPart()
    return safeRead(function()
        local c=self:getCharacter(); if not c.ok then return c end
        local root=self:_entityRoot(c.value); if not root then return readResult(false,"ROOT_PART_UNAVAILABLE") end
        self:_observe("ROOT_PART_READ",{pathOf(root),readProp(root,"ClassName")})
        return readResult(true,"OK",root,{pathOf(root)})
    end)
end
function Slayers2ReadAdapter:_health(entity,property,capability)
    local h=self:_entityHumanoid(entity); if not h then return readResult(false,"HUMANOID_UNAVAILABLE") end
    local v=readProp(h,property)
    if not finite(v) or v<0 then return readResult(false,"HEALTH_UNAVAILABLE") end
    if capability then self:_observe(capability,{pathOf(h).."."..property}) end
    return readResult(true,"OK",v,{pathOf(h).."."..property})
end
function Slayers2ReadAdapter:getHealth() return safeRead(function() local c=self:getCharacter(); if not c.ok then return c end; return self:_health(c.value,"Health","HEALTH_READ") end) end
function Slayers2ReadAdapter:getMaxHealth() return safeRead(function() local c=self:getCharacter(); if not c.ok then return c end; return self:_health(c.value,"MaxHealth","MAX_HEALTH_READ") end) end
function Slayers2ReadAdapter:getNpcHealth(entity) return safeRead(function() return self:_health(entity,"Health") end) end
function Slayers2ReadAdapter:getNpcMaxHealth(entity) return safeRead(function() return self:_health(entity,"MaxHealth") end) end
function Slayers2ReadAdapter:getNpcPosition(entity)
    return safeRead(function()
        local root=self:_entityRoot(entity); local p=root and xyz(readProp(root,"Position"))
        if not p then return readResult(false,"ENTITY_POSITION_UNAVAILABLE") end
        return readResult(true,"OK",p,{pathOf(root)..".Position"})
    end)
end
function Slayers2ReadAdapter:getNpcDistance(entity)
    return safeRead(function()
        local root=self:getRootPart(); if not root.ok then return root end
        local r=self:getNpcPosition(entity); if not r.ok then return r end
        local d=distance(xyz(readProp(root.value,"Position")),r.value)
        if not d then return readResult(false,"DISTANCE_UNAVAILABLE") end
        self:_observe("NPC_POSITION_READ",{pathOf(root.value)..".Position",r.evidence[1],"Euclidean distance between observed BasePart positions"})
        return readResult(true,"OK",d,{pathOf(root.value)..".Position",r.evidence[1]})
    end)
end
function Slayers2ReadAdapter:_structureNode(entity,name)
    if not isInstance(entity) or not readProp(entity,"Parent") then return nil end
    local cursor=entity
    for _=1,3 do
        local node=child(cursor,name)
        if node then return node,cursor end
        cursor=readProp(cursor,"Parent")
        if not cursor then break end
    end
    return nil
end
function Slayers2ReadAdapter:_structure(entity,name)
    if not isInstance(entity) or not readProp(entity,"Parent") then return readResult(false,"ENTITY_UNAVAILABLE") end
    local node=self:_structureNode(entity,name); if not node then return readResult(false,"STRUCTURE_UNAVAILABLE") end
    local out={path=pathOf(node),class=readProp(node,"ClassName"),attributes=attrs(node),values={}}
    local list,truncated=walk(node,100,4); out.truncated=truncated
    for _,x in ipairs(list) do
        if isA(x,"ValueBase") then out.values[pathOf(x)]=scalar(readProp(x,"Value")) end
    end
    -- ModuleScripts are described, never required or evaluated.
    return readResult(true,"OK",out,{out.path})
end
function Slayers2ReadAdapter:getBossInfo(entity) return safeRead(function() return self:_structure(entity,"BossInfo") end) end
function Slayers2ReadAdapter:getNpcConfig(entity) return safeRead(function() return self:_structure(entity,"NpcConfig") end) end
function Slayers2ReadAdapter:getNpcSkills(entity) return safeRead(function() return self:_structure(entity,"Skills") end) end
function Slayers2ReadAdapter:classify(entity)
    return safeRead(function()
        if not isA(entity,"Model") or not readProp(entity,"Parent") then return readResult(false,"INVALID_ENTITY") end
        local c=self:getCharacter()
        local players=self:_service("Players"); local ok,p=pcall(function() return players:GetPlayerFromCharacter(entity) end)
        if (c.ok and c.value==entity) or (ok and p~=nil) then return readResult(true,"OK",{classification="PLAYER",classificationStatus="VERIFIED",combatEligible=false,evidence={pathOf(entity),"Player character identity"}}) end
        local h=self:_entityHumanoid(entity); local root=self:_entityRoot(entity)
        local config=self:_structureNode(entity,"NpcConfig"); local bossInfo=self:_structureNode(entity,"BossInfo"); local a=attrs(entity)
        local ca=attrs(config); local role=a.EntityType or a.NpcType or a.Role or ca.EntityType or ca.NpcType or ca.Role
        for _,v in ipairs(children(config)) do
            local name=readProp(v,"Name")
            if (name=="EntityType" or name=="NpcType" or name=="Role") and isA(v,"StringValue") then role=readProp(v,"Value") end
        end
        local roles={PLAYER="PLAYER",Player="PLAYER",NORMAL_MOB="NORMAL_MOB",NormalMob="NORMAL_MOB",Mob="NORMAL_MOB",Enemy="NORMAL_MOB",BOSS="BOSS",Boss="BOSS",TRAINER="TRAINER",Trainer="TRAINER",QUEST_NPC="QUEST_NPC",QuestNpc="QUEST_NPC",QuestNPC="QUEST_NPC",MERCHANT="MERCHANT",Merchant="MERCHANT"}
        local class=roles[role] or "UNKNOWN"; local evidence={pathOf(entity)}
        if role then table.insert(evidence,"Unconfirmed role field: "..tostring(role)) end
        if h and root and bossInfo then class="BOSS"; table.insert(evidence,pathOf(bossInfo)) end
        if class=="BOSS" or class=="NORMAL_MOB" then
            if not h or not root then class="UNKNOWN" end
        end
        if h then table.insert(evidence,pathOf(h)) end
        if root then table.insert(evidence,pathOf(root)) end
        return readResult(true,"PARTIAL",{classification=class,classificationStatus="PARTIAL",combatEligible=false,structuralCombatCandidate=(class=="BOSS" or class=="NORMAL_MOB") and h~=nil and root~=nil,evidence=evidence})
    end)
end
function Slayers2ReadAdapter:getNpcEntities()
    return safeRead(function()
        local workspaceService=self:_service("Workspace")
        local regions=self:_resolve(workspaceService,{"Humanoids","Regions"})
        if not regions then self.lastEntities={}; return readResult(false,"NPC_REGIONS_UNAVAILABLE") end

        -- Discover only containers that actually exist at runtime. No region name is guessed.
        local regionNodes,regionTruncated=walk(regions,math.min(self.maxNodes,900),math.min(self.maxDepth,8))
        local roots={}; local rootSeen={}
        for _,node in ipairs(regionNodes) do
            if readProp(node,"Name")=="ActiveNpcs" then
                local id=pathOf(node)
                if not rootSeen[id] then
                    rootSeen[id]=true
                    table.insert(roots,node)
                    if #roots>=24 then regionTruncated=true; break end
                end
            end
        end
        if #roots==0 then self.lastEntities={}; return readResult(false,"NPC_CONTAINER_UNAVAILABLE",nil,{pathOf(regions)}) end

        local rootEvidence={}
        for _,root in ipairs(roots) do table.insert(rootEvidence,pathOf(root)) end
        self:_observe("NPC_CONTAINER",rootEvidence)

        local out={}; local included={}; local recordSeen={}; local truncated=regionTruncated
        local remaining=self.maxNodes
        self.lastEntities={}
        for _,root in ipairs(roots) do
            if remaining<=0 then truncated=true; break end
            local list,rootTruncated=walk(root,remaining,self.maxDepth)
            remaining=math.max(0,remaining-#list)
            truncated=truncated or rootTruncated
            for _,entity in ipairs(list) do
                if entity~=root and isA(entity,"Model") then
                    local ancestor=readProp(entity,"Parent"); local nested=false
                    while ancestor and ancestor~=root do if included[ancestor] then nested=true; break end; ancestor=readProp(ancestor,"Parent") end
                    if not nested then
                        local classification=self:classify(entity)
                        local hasStructure=self:_entityHumanoid(entity) or child(entity,"NpcConfig") or child(entity,"BossInfo") or child(entity,"Skills")
                        if hasStructure and classification.ok and classification.value.classification~="PLAYER" then
                            included[entity]=true
                            local p=self:getNpcPosition(entity); local d=self:getNpcDistance(entity); local hp=self:getNpcHealth(entity); local max=self:getNpcMaxHealth(entity)
                            local id=pathOf(entity)
                            if not recordSeen[id] then
                                recordSeen[id]=true
                                local evidence=Util.deepCopy(classification.value.evidence or {})
                                table.insert(evidence,"ActiveNpcs container: "..pathOf(root))
                                local record={id=id,name=readProp(entity,"Name"),position=p.ok and p.value or nil,distance=d.ok and d.value or nil,health=hp.ok and hp.value or nil,maxHealth=max.ok and max.value or nil,alive=hp.ok and hp.value>0 or false,aliveKnown=hp.ok,classification=classification.value.classification,classificationStatus=classification.value.classificationStatus,combatEligible=false,evidence=evidence,locationConfirmed=false}
                                record.isBoss=record.classification=="BOSS"; record.present=true
                                table.insert(out,record); self.lastEntities[id]=entity
                            end
                        end
                    end
                end
            end
        end
        table.sort(out,function(a,b) return a.id<b.id end)
        local enumEvidence=Util.deepCopy(rootEvidence); table.insert(enumEvidence,"Bounded multi-region ActiveNpcs enumeration")
        self:_observe("NPC_ENUMERATION",enumEvidence)
        local r=readResult(true,"PARTIAL",out,rootEvidence); r.metadata.truncated=truncated; r.metadata.containerCount=#roots; r.metadata.classification="Structural candidates; semantic mapping unconfirmed"
        return r
    end)
end
function Slayers2ReadAdapter:getBossEntities()
    return safeRead(function()
        local all=self:getNpcEntities(); if not all.ok then return all end
        local out={}; for _,x in ipairs(all.value) do if x.classification=="BOSS" then table.insert(out,x) end end
        return readResult(true,"PARTIAL",out,all.evidence)
    end)
end
function Slayers2ReadAdapter:_findSkillHolder()
    local direct=self:_gui({"ComponentsHolder","BottomHolder","SkillsHolder"})
    if direct then return direct,{pathOf(direct),"Direct verified V2 candidate path"} end
    local root=self:_gui({"ComponentsHolder"})
    if not root then return nil,{} end
    local nodes=walk(root,700,8)
    for _,x in ipairs(nodes) do
        if readProp(x,"Name")=="1-Skill" then
            local parent=readProp(x,"Parent")
            if parent then return parent,{pathOf(parent),"Fallback holder inferred only from exact child name 1-Skill"} end
        end
    end
    return nil,{}
end
local function keyCode(text)
    if type(text)~="string" then return nil end
    local clean=string.upper((string.gsub(text,"%s+","")))
    if clean=="" or #clean>6 then return nil end
    local ok,val=pcall(function() return Enum.KeyCode[clean] end)
    return ok and val or nil
end
function Slayers2ReadAdapter:getSkillSlots()
    return safeRead(function()
        local holder,holderEvidence=self:_findSkillHolder()
        if not holder then return readResult(false,"SKILL_HOLDER_UNAVAILABLE") end
        self:_observe("SKILL_HOLDER",holderEvidence)
        local out={}; local source,truncated=walk(holder,350,6)
        for i=1,10 do
            local slot=child(holder,tostring(i).."-Skill")
            if not slot then for _,x in ipairs(source) do if readProp(x,"Name")==tostring(i).."-Skill" then slot=x; break end end end
            if slot then
                local record={index=i,path=pathOf(slot),visible=readProp(slot,"Visible"),attributes=attrs(slot),text={},imageIds={},cooldownOverlays={},cooldownCandidates={},keybindCandidates={},skillNameCandidates={},skillName=nil,available=nil,availabilityStatus="UNRESOLVED_GAME_BINDING"}
                local nodes,cut=walk(slot,80,5); record.truncated=cut
                for _,x in ipairs(nodes) do
                    local name=string.lower(tostring(readProp(x,"Name") or "")); local textValue=readProp(x,"Text")
                    if type(textValue)=="string" and textValue~="" then table.insert(record.text,{path=pathOf(x),text=string.sub(textValue,1,512)}) end
                    if name=="skillname" or name=="title" then table.insert(record.skillNameCandidates,{path=pathOf(x),text=textValue}) end
                    if isA(x,"ImageLabel") or isA(x,"ImageButton") then table.insert(record.imageIds,{path=pathOf(x),image=readProp(x,"Image")}) end
                    if string.find(name,"cooldown",1,true) or name=="cd" then
                        table.insert(record.cooldownOverlays,{path=pathOf(x),visible=readProp(x,"Visible"),text=textValue,size=tostring(readProp(x,"Size"))})
                        table.insert(record.cooldownCandidates,{path=pathOf(x),value=isA(x,"ValueBase") and scalar(readProp(x,"Value")) or textValue,attributes=attrs(x)})
                    end
                    -- v3.8.4.2 keybind discovery (live evidence: <n>-Skill.<Skills_nth>.KeyLabel.Text = "F"/"Z"/...)
                    -- priority 1 KEYLABEL_VERIFIED · 2 EXPLICIT_NAME · 3 ATTRIBUTE · 4 VISIBLE_TEXT
                    local shortKey=type(textValue)=="string" and #textValue>0 and #textValue<=6 and keyCode(textValue)~=nil
                    local shown=readProp(x,"Visible")~=false
                    if name=="keylabel" and shortKey and shown then
                        table.insert(record.keybindCandidates,{path=pathOf(x),text=textValue,attributes=attrs(x),source="KEYLABEL_VERIFIED",rank=1})
                    elseif (string.find(name,"keybind",1,true) or name=="key") and shortKey then
                        table.insert(record.keybindCandidates,{path=pathOf(x),text=textValue,attributes=attrs(x),source="EXPLICIT_NAME",rank=2})
                    elseif shortKey and shown and (isA(x,"TextLabel") or isA(x,"TextButton")) and string.len(textValue)<=2 then
                        table.insert(record.keybindCandidates,{path=pathOf(x),text=textValue,attributes=attrs(x),source="VISIBLE_TEXT",rank=4})
                    end
                    for ak,av in pairs(attrs(x) or {}) do
                        local lk=string.lower(tostring(ak))
                        if (string.find(lk,"keybind",1,true) or lk=="key" or lk=="hotkey") and type(av)=="string" and #av<=6 and keyCode(av) then
                            table.insert(record.keybindCandidates,{path=pathOf(x).."@"..tostring(ak),text=av,attributes={},source="ATTRIBUTE",rank=3})
                        end
                    end
                end
                table.sort(record.keybindCandidates,function(a,b) return (a.rank or 9)<(b.rank or 9) end)
                record.keySource=record.keybindCandidates[1] and record.keybindCandidates[1].source or nil
                table.insert(out,record)
            end
        end
        local r=readResult(true,"PARTIAL",out,holderEvidence); r.metadata.truncated=truncated
        if #out>0 then self:_observe("SKILL_SLOT_READ",{pathOf(holder),"Exact 1-Skill through 10-Skill names; GUI property reads only"}) end
        return r
    end)
end
function Slayers2ReadAdapter:getAvailableSkills()
    local r=self:getSkillSlots(); if not r.ok then return r end
    return readResult(true,"PARTIAL",{slots=r.value,availableSkills={},availabilityKnown=false,reason="Cooldown/name/key semantics require manual combat diff confirmation"},r.evidence)
end
function Slayers2ReadAdapter:_expCandidates(field)
    local root=self:_gui({"ComponentsHolder","LeftHudPortion","ExpFrame"})
    if not root then return readResult(false,"EXP_FRAME_UNAVAILABLE") end
    local out={}; local nodes,truncated=walk(root,160,6)
    for _,x in ipairs(nodes) do
        local textValue=readProp(x,"Text"); local value=isA(x,"ValueBase") and scalar(readProp(x,"Value")) or nil
        if textValue~=nil or value~=nil or next(attrs(x)) then table.insert(out,{path=pathOf(x),text=scalar(textValue),value=value,attributes=attrs(x)}) end
    end
    local r=readResult(false,"UNRESOLVED_GAME_BINDING",nil,{pathOf(root)}); r.candidates=out; r.metadata={field=field,truncated=truncated}
    return r
end
function Slayers2ReadAdapter:_expContext()
    return self:_gui({"ComponentsHolder","LeftHudPortion","ExpFrame","Context"})
end
function Slayers2ReadAdapter:getLevel()
    return safeRead(function()
        local context=self:_expContext(); local label=context and child(context,"Level")
        local raw=label and readProp(label,"Text")
        if type(raw)=="string" then
            local n=tonumber(string.match(raw,"^%s*[Ll][Vv]%s*(%d+)%s*$"))
            if n and n>=0 and n%1==0 then
                local evidence={pathOf(label)..".Text","Observed live format: Lv <integer>"}
                self:_observe("LEVEL_READ",evidence)
                return readResult(true,"OK",n,evidence)
            end
        end
        return self:_expCandidates("Level")
    end)
end
function Slayers2ReadAdapter:_readXpPair()
    local context=self:_expContext(); local label=context and child(context,"Exp")
    local raw=label and readProp(label,"Text")
    if type(raw)=="string" then
        local current,required=string.match(raw,"^%s*(%d+)%s*/%s*(%d+)%s*$")
        current=tonumber(current); required=tonumber(required)
        if current and required and current>=0 and required>0 then
            local evidence={pathOf(label)..".Text","Observed live format: <current> / <required>"}
            return readResult(true,"OK",{current=current,required=required},evidence)
        end
    end
    return self:_expCandidates("XP")
end
function Slayers2ReadAdapter:getXP()
    return safeRead(function()
        local r=self:_readXpPair()
        if r.ok then self:_observe("XP_READ",r.evidence); return readResult(true,"OK",r.value.current,r.evidence) end
        r.metadata=r.metadata or {}; r.metadata.field="XP"; return r
    end)
end
function Slayers2ReadAdapter:getXPRequired()
    return safeRead(function()
        local r=self:_readXpPair()
        if r.ok then self:_observe("XP_REQUIRED_READ",r.evidence); return readResult(true,"OK",r.value.required,r.evidence) end
        r.metadata=r.metadata or {}; r.metadata.field="XPRequired"; return r
    end)
end
function Slayers2ReadAdapter:getQuestState()
    return safeRead(function()
        local root=child(self:_player(),"PlayerGui"); if not root then return readResult(false,"PLAYER_GUI_UNAVAILABLE") end
        local out={}; local nodes,truncated=walk(root,self.maxNodes,self.maxDepth)
        for _,x in ipairs(nodes) do
            local name=string.lower(tostring(readProp(x,"Name") or ""))
            if string.find(name,"quest",1,true) or string.find(name,"objective",1,true) or string.find(name,"mission",1,true) then
                table.insert(out,{path=pathOf(x),class=readProp(x,"ClassName"),text=scalar(readProp(x,"Text")),visible=readProp(x,"Visible"),attributes=attrs(x)})
            end
        end
        local r=readResult(false,"UNRESOLVED_GAME_BINDING"); r.candidates=out; r.metadata={truncated=truncated,reason="Use paired Quest Probe; candidate paths do not establish quest semantics"}; return r
    end)
end
function Slayers2ReadAdapter:getBossMarkers()
    return safeRead(function()
        local holder=self:_gui({"ComponentsHolder","Minimap","FadeMask","PinsHolder","Bosses"})
        if not holder then return readResult(false,"BOSS_MARKER_CONTAINER_UNAVAILABLE") end
        self:_observe("BOSS_MARKER_CONTAINER",{pathOf(holder)})
        local out={}
        for _,x in ipairs(children(holder)) do
            local class=readProp(x,"ClassName")
            if class=="Frame" or class=="ImageLabel" or class=="ImageButton" then
                local label=child(x,"Label")
                table.insert(out,{path=pathOf(x),name=readProp(x,"Name"),class=class,visible=readProp(x,"Visible"),text=label and scalar(readProp(label,"Text")) or scalar(readProp(x,"Text")),attributes=attrs(x),guiPosition=tostring(readProp(x,"Position")),worldPosition=nil})
            end
        end
        table.sort(out,function(a,b) return tostring(a.name)<tostring(b.name) end)
        local r=readResult(true,"PARTIAL",out,{pathOf(holder)})
        r.metadata={truncated=false,reason="Direct minimap markers only; GUI coordinates are not world destinations"}
        return r
    end)
end
Slayers2ReadAdapter.helpers={readProp=readProp,isInstance=isInstance,isA=isA,child=child,children=children,pathOf=pathOf,attrs=attrs,xyz=xyz,scalar=scalar,walk=walk,safeRead=safeRead,result=readResult}
Modules.Slayers2ReadAdapter=Slayers2ReadAdapter

CTX["Slayers2ReadAdapter"]=Slayers2ReadAdapter
CTX["readResult"]=readResult
CTX["readProp"]=readProp
CTX["isInstance"]=isInstance
CTX["isA"]=isA
CTX["child"]=child
CTX["children"]=children
CTX["pathOf"]=pathOf
CTX["attrs"]=attrs
CTX["xyz"]=xyz
CTX["scalar"]=scalar
CTX["walk"]=walk
CTX["safeRead"]=safeRead
return true]==========]); if not ok then return end end
do local ok=runChunk("BindingProbe.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Modules=CTX["Modules"]
local Logger=CTX["Logger"]
local FSM=CTX["FSM"]
local classify=CTX["classify"]
local result=CTX["result"]
local finite=CTX["finite"]
local distance=CTX["distance"]
local FeatureRegistry=CTX["FeatureRegistry"]
local RAVYN=CTX["RAVYN"]
local Slayers2ReadAdapter=CTX["Slayers2ReadAdapter"]
local readProp=CTX["readProp"]
local isA=CTX["isA"]
local child=CTX["child"]
local children=CTX["children"]
local pathOf=CTX["pathOf"]
local attrs=CTX["attrs"]
local xyz=CTX["xyz"]
local scalar=CTX["scalar"]
local walk=CTX["walk"]
local safeRead=CTX["safeRead"]
-- Targeted, bounded snapshots. Captures never perform game interactions.
local Probe={}; Probe.__index=Probe
local H=Slayers2ReadAdapter.helpers
local function serialize(v,depth)
    depth=depth or 0
    if type(v)=="string" then return string.format("%q",v) end
    if type(v)=="number" or type(v)=="boolean" then return tostring(v) end
    if type(v)~="table" then return "null" end
    if depth>12 then return '"<depth-limit>"' end
    local keys={}; for k in pairs(v) do table.insert(keys,k) end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    local out={}; for _,k in ipairs(keys) do table.insert(out,string.format("%q",tostring(k))..":"..serialize(v[k],depth+1)) end
    return "{"..table.concat(out,",").."}"
end
local questWords={"quest","mission","objective","progress","required","complete","target","kill","amount","reward"}
local combatWords={"combat","attack","weapon","target","health","skill","cooldown","block","parry","equipped","damage","stun"}
local function matches(text,words)
    text=string.lower(tostring(text or ""))
    for _,w in ipairs(words) do if string.find(text,w,1,true) then return true end end
    return false
end
function Probe.new(adapter)
    return setmetatable({adapter=adapter,captures={Quest={},Combat={}},maxRecords=2400,maxDiff=600,targetId=nil,sequence=0},Probe)
end
function Probe:setTarget(query)
    return H.safeRead(function()
        local entities=self.adapter:getNpcEntities(); if not entities.ok then return entities end
        local found={}
        for _,x in ipairs(entities.value) do if x.id==query or x.name==query then table.insert(found,x) end end
        if #found~=1 then return H.result(false,#found==0 and "TARGET_NOT_FOUND" or "AMBIGUOUS_TARGET",found) end
        self.targetId=found[1].id; return H.result(true,"TARGET_SELECTED",found[1])
    end)
end
function Probe:capture(kind,label)
    return H.safeRead(function()
        if not self.captures[kind] then return H.result(false,"INVALID_PROBE") end
        local permitted={Quest={Before=true,After=true},Combat={Idle=true,Target=true,Attack=true,Kill=true}}
        if not permitted[kind][label] then return H.result(false,"INVALID_CAPTURE_LABEL") end
        local adapter=self.adapter; local p=adapter:_player(); local c=adapter:getCharacter()
        if not p then return H.result(false,"LOCAL_PLAYER_UNAVAILABLE") end
        self.sequence=self.sequence+1
        local snap={kind=kind,label=label,sequence=self.sequence,time=adapter.clock(),targetId=self.targetId,character=c.ok and H.pathOf(c.value) or nil,records={},recordCount=0,truncated=false,readErrors={}}
        local words=kind=="Quest" and questWords or combatWords
        local function add(key,value)
            value=H.scalar(value); if value==nil then return end
            if snap.recordCount>=self.maxRecords then snap.truncated=true; return end
            if snap.records[key]==nil then snap.recordCount=snap.recordCount+1 end
            snap.records[key]=value
        end
        local function inspect(root,allRelevant)
            if not root then return end
            local nodes,cut=H.walk(root,adapter.maxNodes,adapter.maxDepth); snap.truncated=snap.truncated or cut
            local inherited={}
            for _,x in ipairs(nodes) do
                local path=H.pathOf(x); local parent=H.readProp(x,"Parent")
                local relevant=allRelevant or inherited[parent] or matches(H.readProp(x,"Name"),words)
                inherited[x]=relevant
                if relevant then
                    add(path..".@exists",true); add(path..".@class",H.readProp(x,"ClassName"))
                    if H.isA(x,"GuiObject") then add(path..".Visible",H.readProp(x,"Visible")) end
                    if H.isA(x,"TextLabel") or H.isA(x,"TextButton") or H.isA(x,"TextBox") then add(path..".Text",H.readProp(x,"Text")) end
                    if H.isA(x,"ValueBase") then add(path..".Value",H.readProp(x,"Value")) end
                    if H.isA(x,"BasePart") then add(path..".Position",H.readProp(x,"Position")) end
                    if H.isA(x,"ImageLabel") or H.isA(x,"ImageButton") then add(path..".Image",H.readProp(x,"Image")); add(path..".ImageTransparency",H.readProp(x,"ImageTransparency")) end
                    if H.isA(x,"GuiObject") and matches(H.readProp(x,"Name"),{"cooldown","overlay","fill"}) then add(path..".Size",tostring(H.readProp(x,"Size"))) end
                end
                for key,value in pairs(H.attrs(x)) do if relevant or matches(key,words) then add(path..".Attribute."..tostring(key),value) end end
            end
        end
        -- Do not scan all Workspace or any remote container. Focus on known GUI roots.
        inspect(H.child(p,"PlayerGui"),false)
        for key,value in pairs(H.attrs(p)) do if matches(key,words) then add(H.pathOf(p)..".Attribute."..tostring(key),value) end end
        for _,x in ipairs(H.children(p)) do if H.isA(x,"ValueBase") or matches(H.readProp(x,"Name"),words) then inspect(x,matches(H.readProp(x,"Name"),words)) end end
        if c.ok then
            inspect(c.value,false)
            for key,value in pairs(H.attrs(c.value)) do if matches(key,words) then add(H.pathOf(c.value)..".Attribute."..tostring(key),value) end end
            local humanoid=adapter:getHumanoid()
            if kind=="Combat" and humanoid.ok then add(H.pathOf(humanoid.value)..".Health",H.readProp(humanoid.value,"Health")); add(H.pathOf(humanoid.value)..".MaxHealth",H.readProp(humanoid.value,"MaxHealth")) end
        else table.insert(snap.readErrors,c.code) end
        if kind=="Combat" then inspect(adapter:_gui({"ComponentsHolder","BottomHolder","SkillHolder"}),true) end
        local entities=adapter:getNpcEntities()
        if entities.ok then
            snap.truncated=snap.truncated or entities.metadata.truncated
            for _,entity in ipairs(entities.value) do
                if not self.targetId or entity.id==self.targetId or kind=="Quest" then
                    local raw=adapter.lastEntities[entity.id]
                    if kind=="Combat" then
                        add(entity.id..".Observed.Health",entity.health); add(entity.id..".Observed.MaxHealth",entity.maxHealth); add(entity.id..".Observed.Alive",entity.aliveKnown and entity.alive)
                        inspect(raw,false); inspect(H.child(raw,"Skills"),true)
                    else
                        inspect(raw,false)
                        -- Prompt indicators describe manual interactions, never trigger them.
                        local nodes,cut=H.walk(raw,150,5); snap.truncated=snap.truncated or cut
                        for _,x in ipairs(nodes) do if H.isA(x,"ProximityPrompt") then
                            add(H.pathOf(x)..".Enabled",H.readProp(x,"Enabled")); add(H.pathOf(x)..".ActionText",H.readProp(x,"ActionText")); add(H.pathOf(x)..".ObjectText",H.readProp(x,"ObjectText"))
                        end end
                    end
                end
            end
        else table.insert(snap.readErrors,entities.code) end
        self.captures[kind][label]=snap
        return H.result(true,"CAPTURED_"..string.upper(kind).."_"..string.upper(label),snap)
    end)
end
function Probe.diff(before,after,maxDiff)
    if not before or not after then return H.result(false,"CAPTURES_REQUIRED") end
    if before.sequence>=after.sequence then return H.result(false,"CAPTURE_ORDER_INVALID") end
    local keys={}; for k in pairs(before.records) do keys[k]=true end; for k in pairs(after.records) do keys[k]=true end
    local sorted={}; for k in pairs(keys) do table.insert(sorted,k) end; table.sort(sorted)
    local out={from=before.label,to=after.label,changes={},totalChanges=0,truncated=before.truncated or after.truncated,characterChanged=before.character~=after.character,targetChanged=before.targetId~=after.targetId,fields={questName={},target={},progress={},requiredAmount={},completion={},objectiveLocation={}}}
    for _,path in ipairs(sorted) do
        local a,b=before.records[path],after.records[path]
        if a~=b then
            out.totalChanges=out.totalChanges+1
            if #out.changes<(maxDiff or 600) then
                local change={path=path,before=a,after=b,change=a==nil and "ADDED" or b==nil and "REMOVED" or "CHANGED"}
                table.insert(out.changes,change)
                local lower=string.lower(path); local v=b~=nil and b or a
                local candidate={path=path,value=v,status="CANDIDATE_UNCONFIRMED"}
                if matches(lower,{"questname","questtitle","missionname"}) then table.insert(out.fields.questName,candidate) end
                if matches(lower,{"target","enemyname"}) then table.insert(out.fields.target,candidate) end
                if matches(lower,{"progress","killcount"}) then table.insert(out.fields.progress,candidate) end
                if matches(lower,{"required","amount","goal"}) then table.insert(out.fields.requiredAmount,candidate) end
                if matches(lower,{"complete","finished","reward"}) then table.insert(out.fields.completion,candidate) end
                if matches(lower,{"objective","target"}) and matches(lower,{"position","location"}) then table.insert(out.fields.objectiveLocation,candidate) end
                if type(v)=="string" then
                    local current,required=string.match(v,"(%d+)%s*/%s*(%d+)")
                    if current then table.insert(out.fields.progress,{path=path,value=tonumber(current),status="TEXT_PATTERN_CANDIDATE"}); table.insert(out.fields.requiredAmount,{path=path,value=tonumber(required),status="TEXT_PATTERN_CANDIDATE"}) end
                end
            else out.truncated=true end
        end
    end
    out.note="Candidate fields require manual confirmation; absent fields remain unknown. No action semantics inferred."
    return H.result(true,"DIFF_READY",out)
end
function Probe:compareQuest() return H.safeRead(function() return Probe.diff(self.captures.Quest.Before,self.captures.Quest.After,self.maxDiff) end) end
function Probe:compareCombat()
    return H.safeRead(function()
        local labels={"Idle","Target","Attack","Kill"}; local comparisons={}
        for i=1,3 do
            local r=Probe.diff(self.captures.Combat[labels[i]],self.captures.Combat[labels[i+1]],self.maxDiff)
            if not r.ok then return r end
            table.insert(comparisons,r.value)
        end
        return H.result(true,"COMBAT_DIFF_READY",comparisons)
    end)
end
Probe.serialize=serialize
Modules.BindingProbe=Probe

-- Evidence describes exact capabilities. Previously reported live paths are kept
-- distinct from current code execution and unconfirmed semantic mappings.
local reported={
 CHARACTER_LOOKUP={"game.Workspace.Humanoids.<LocalPlayerName>","User reports successful V2 live discovery"},
 HEALTH_READ={"Humanoid.Health","User-reported live read: 833"},
 MAX_HEALTH_READ={"Humanoid.MaxHealth","User-reported live read: 833"},
 NPC_CONTAINER={"game.Workspace.Humanoids.Regions.Misc.ActiveNpcs","User reports live container discovery"},
 SKILL_HOLDER={"game.Players.LocalPlayer.PlayerGui.ComponentsHolder.BottomHolder.SkillsHolder","User reports slots 1-Skill through 10-Skill"},
 BOSS_MARKER_CONTAINER={"game.Players.Fake2us.PlayerGui.ComponentsHolder.Minimap.FadeMask.PinsHolder.Bosses","v3.1 live read 2026-09-26; GUI container only"},
 ROOT_PART_READ={"game.Workspace.Humanoids.Fake2us.HumanoidRootPart","v3.1 live read 2026-09-26"},
 NPC_ENUMERATION={"game.Workspace.Humanoids.Regions.Misc.ActiveNpcs","v3.1 live bounded enumeration 2026-09-26"},
 NPC_POSITION_READ={"game.Workspace.Humanoids.Fake2us.HumanoidRootPart.Position","game.Workspace.Humanoids.Regions.Misc.ActiveNpcs.Soryu Trainee Goki.Soryu Trainee Goki.HumanoidRootPart.Position","v3.1 live Euclidean distance read 2026-09-26"},
 LEVEL_READ={"game.Players.Fake2us.PlayerGui.ComponentsHolder.LeftHudPortion.ExpFrame.Context.Level.Text = Lv 122","v3.1 live read 2026-09-26"},
 XP_READ={"game.Players.Fake2us.PlayerGui.ComponentsHolder.LeftHudPortion.ExpFrame.Context.Exp.Text = 2121 / 3327","v3.1 live read 2026-09-26"},
 XP_REQUIRED_READ={"game.Players.Fake2us.PlayerGui.ComponentsHolder.LeftHudPortion.ExpFrame.Context.Exp.Text = 2121 / 3327","v3.1 live read 2026-09-26"},
}
local capabilitySpecs={
 {"CHARACTER_LOOKUP","Character lookup","getCharacter","VERIFIED"},
 {"HEALTH_READ","Health","getHealth","VERIFIED"},{"MAX_HEALTH_READ","Max health","getMaxHealth","VERIFIED"},
 {"NPC_CONTAINER","NPC region","getNpcEntities","VERIFIED"},
 {"ROOT_PART_READ","Character root","getRootPart","VERIFIED"},
 {"NPC_ENUMERATION","NPC model enumeration","getNpcEntities","VERIFIED"},
 {"NPC_POSITION_READ","NPC position/distance","getNpcPosition / getNpcDistance","VERIFIED"},
 {"BOSS_ENUMERATION","Structural boss candidates","getBossEntities","PARTIAL"},
 {"MOB_CLASSIFICATION","Structural normal-mob candidates","classify","PARTIAL"},
 {"SKILL_HOLDER","Skill holder","getSkillSlots","VERIFIED"},
 {"SKILL_SLOT_READ","Skill GUI properties","getSkillSlots","VERIFIED"},
 {"SKILL_AVAILABILITY","Skill cooldown/availability semantics","getAvailableSkills","UNRESOLVED_GAME_BINDING"},
 {"LEVEL_READ","Level","getLevel","VERIFIED"},{"XP_READ","Current XP","getXP","VERIFIED"},{"XP_REQUIRED_READ","Required XP","getXPRequired","VERIFIED"},
 {"QUEST_READ","Quest state semantics","Quest Before/After Probe","PARTIAL"},
 {"BOSS_MARKER_CONTAINER","Boss minimap container","getBossMarkers","VERIFIED"},
 {"BOSS_MARKER_WORLD_POSITION","Boss pin world coordinates","getBossMarkers","UNRESOLVED_GAME_BINDING"},
 {"MUZAN_IDENTITY","Muzan identity","Exact-name candidate only","UNRESOLVED_GAME_BINDING"},
 {"ROAMING_MUZAN_IDENTITY","Roaming Muzan identity","Exact-name candidate only","UNRESOLVED_GAME_BINDING"},
 {"MARKETER_IDENTITY","Black Marketer identity","Exact-name/structure candidate only","UNRESOLVED_GAME_BINDING"},
 {"YETI_IDENTITY","Frozen Yeti identity","Exact-name candidate only","UNRESOLVED_GAME_BINDING"},
 {"WORLD_EVENTS_READ","World/event semantics","No confirmed state source","UNRESOLVED_GAME_BINDING"},
}
local featureReads={NORMAL_MOB={"NPC_CONTAINER","NPC_ENUMERATION","NPC_POSITION_READ","MOB_CLASSIFICATION"},BOSS={"NPC_CONTAINER","BOSS_ENUMERATION","NPC_POSITION_READ"},AUTO_QUEST={"QUEST_READ"},QUEST_HIGHLIGHT={"QUEST_READ"},ATTACK={"HEALTH_READ","NPC_POSITION_READ"},ABILITIES={"SKILL_HOLDER","SKILL_SLOT_READ","SKILL_AVAILABILITY"},PARRY={"HEALTH_READ"},EQUIP={"CHARACTER_LOOKUP"},SPEED={"CHARACTER_LOOKUP","ROOT_PART_READ"},NPC_TELEPORT={"NPC_CONTAINER","NPC_POSITION_READ"},TRAINING_TELEPORT={"NPC_CONTAINER"},MUZAN_QUEST={"QUEST_READ"},CROW_QUEST={"QUEST_READ"},MUZAN_TRACK={"NPC_CONTAINER","NPC_POSITION_READ","MUZAN_IDENTITY"},ROAMING_MUZAN={"NPC_CONTAINER","NPC_POSITION_READ","ROAMING_MUZAN_IDENTITY"},MARKETER_TRACK={"NPC_CONTAINER","NPC_POSITION_READ","MARKETER_IDENTITY"},YETI_FARM={"NPC_CONTAINER","NPC_POSITION_READ","YETI_IDENTITY"},YETI_TELEPORT={"NPC_CONTAINER","NPC_POSITION_READ","YETI_IDENTITY"},WORLD_EVENTS={"WORLD_EVENTS_READ"},MERCHANT={"MARKETER_IDENTITY"}}
RAVYN.Version="3.4.0-live"
RAVYN.Build="2026-09-26-v3.4-client-live"
RAVYN.ReadAdapter=Slayers2ReadAdapter.new()
RAVYN.Probes=Probe.new(RAVYN.ReadAdapter)
RAVYN.ProbeReport="Run Live Read Scan. Level/XP parser is evidence-bound; actions remain disabled. Then capture Quest and Combat diffs."
RAVYN.ProbeOnly=true
RAVYN.BindingCapabilities={}
for _,spec in ipairs(capabilitySpecs) do
    RAVYN.BindingCapabilities[spec[1]]={id=spec[1],name=spec[2],binding=spec[3],bindingStatus=spec[4],evidence=reported[spec[1]] or {},lastVerified=nil,liveTested=reported[spec[1]]~=nil,currentCodeLiveTested=false,provenance=reported[spec[1]] and "USER_REPORTED_V2_LIVE_FACT" or "AWAITING_LIVE_MAPPING"}
end
-- Action capabilities stay unresolved even when their adjacent read source is known.
local actionNames={"MOVE","TELEPORT","SPEED_WRITE","ATTACK","ABILITY","PARRY","EQUIP","QUEST_ACCEPT","QUEST_COMPLETE","HIGHLIGHT","OPEN_CHEST","COLLECT_DROP","COLLECT_SOUL","COLLECT_SCHEMATIC","OPEN_SEALED_CHEST","TRAINING_INTERACT","JOIN_OUWLAND","FISH_START","FISH_INPUT","COLLECT_FISH","ROD_UPGRADE","QUEUE_NORMAL","READY","LEAVE","VOTE","SELECT_CARD","PURCHASE"}
for _,id in ipairs(actionNames) do RAVYN.BindingCapabilities[id]={id=id,name=id,binding="No action binding installed",bindingStatus="UNRESOLVED_GAME_BINDING",evidence={},liveTested=false,currentCodeLiveTested=false} end
local registryRefresh=FeatureRegistry.refresh
function FeatureRegistry:refresh()
    registryRefresh(self)
    if not self.probeRuntime then return end
    for _,f in ipairs(self.order) do
        f.evidence={}; f.lastVerified=nil; f.liveTested=false; f.readCapabilities=featureReads[f.id] or {}
        local any=false
        for _,id in ipairs(f.readCapabilities) do
            local c=self.probeRuntime.BindingCapabilities[id]
            if c and c.bindingStatus~="UNRESOLVED_GAME_BINDING" then any=true end
            for _,e in ipairs(c and c.evidence or {}) do table.insert(f.evidence,e) end
        end
        f.bindingStatus=any and "PARTIAL" or "UNRESOLVED_GAME_BINDING"
        f.available=false; f.status="PROBE_ONLY / "..f.bindingStatus
        f.note="Read mapping only; full feature actions and semantic identities are not verified."
    end
end
RAVYN.Registry.probeRuntime=RAVYN
RAVYN.Registry:refresh()
function RAVYN:RegisterBinding() return result(false,"PROBE_READ_ONLY_NO_ACTION_REGISTRATION") end
function RAVYN:TeleportTo() return result(false,"PROBE_READ_ONLY_MOVEMENT_DISABLED") end
function RAVYN:SetProbeTarget(query) return self.Probes:setTarget(query) end
function RAVYN:_showReport(kind,value)
    self.ProbeReport="RAVYN v3.4 | "..kind.."\n"..serialize(value)
    return self.ProbeReport
end
function RAVYN:GetBindingInspector()
    local rows={}
    for _,f in ipairs(self.Registry.order) do
        for _,id in ipairs(f.readCapabilities or {}) do
            local c=self.BindingCapabilities[id]
            table.insert(rows,{feature=f.name,capability=id,binding=c.binding,status=c.bindingStatus,evidence=c.evidence,liveTested=c.liveTested,currentCodeLiveTested=c.currentCodeLiveTested,lastVerified=c.lastVerified,provenance=c.provenance})
        end
        for _,id in ipairs(f.dependencies) do
            local c=self.BindingCapabilities[id] or {binding="No confirmed normalized capability installed",bindingStatus="UNRESOLVED_GAME_BINDING",evidence={},liveTested=false}
            table.insert(rows,{feature=f.name,capability=id,binding=c.binding,status=c.bindingStatus,evidence=c.evidence,liveTested=c.liveTested,lastVerified=c.lastVerified})
        end
    end
    return rows
end
function RAVYN:RefreshReadBindings()
    return H.safeRead(function()
        if self._destroyed then return result(false,"DESTROYED") end
        local a=self.ReadAdapter; local health=a:getHealth(); local max=a:getMaxHealth(); local root=a:getRootPart(); local char=a:getCharacter(); local entities=a:getNpcEntities(); local slots=a:getSkillSlots(); local markers=a:getBossMarkers(); local level=a:getLevel(); local xp=a:getXP(); local xpRequired=a:getXPRequired(); local quest=a:getQuestState()
        local s={player={health=health.ok and health.value or nil,maxHealth=max.ok and max.value or nil,position=root.ok and H.xyz(H.readProp(root.value,"Position")) or nil,characterId=char.ok and H.pathOf(char.value) or nil,characterValid=char.ok,rootValid=root.ok},npcs=entities.ok and entities.value or {},mobs={},bosses={}}
        if health.ok and max.ok and max.value>0 then s.player.healthPercent=health.value/max.value*100; s.player.dead=health.value<=0 end
        for _,entity in ipairs(s.npcs) do
            if entity.classification=="BOSS" then table.insert(s.bosses,entity) elseif entity.classification=="NORMAL_MOB" then table.insert(s.mobs,entity) end
        end
        self.Features.snapshot=s
        local tracks={}
        local identities={Muzan="Muzan",["Roaming Muzan"]="Roaming Muzan",["Black Marketer"]="Black Marketer",["Frozen Yeti"]="Frozen Yeti"}
        for _,entity in ipairs(s.npcs) do if identities[entity.name] then table.insert(tracks,{candidate=entity.name,entity=entity,identityStatus="UNRESOLVED_GAME_BINDING"}) end end
        self.ProbeTrackerCandidates=tracks
        for id,e in pairs(a.evidence) do
            local cap=self.BindingCapabilities[id]
            if cap then cap.currentCodeLiveTested=e.liveTested; cap.runtimeObservation=e; cap.lastVerified=e.lastVerified
                if e.liveTested then cap.bindingStatus=e.bindingStatus; cap.evidence=e.evidence; cap.liveTested=true; cap.provenance=e.source end
            end
        end
        local currentReads={CHARACTER_LOOKUP=char,HEALTH_READ=health,MAX_HEALTH_READ=max,ROOT_PART_READ=root,NPC_CONTAINER=entities,NPC_ENUMERATION=entities,SKILL_HOLDER=slots,SKILL_SLOT_READ=slots,BOSS_MARKER_CONTAINER=markers,LEVEL_READ=level,XP_READ=xp,XP_REQUIRED_READ=xpRequired}
        for id,reading in pairs(currentReads) do
            local cap=self.BindingCapabilities[id]
            cap.currentAvailable=reading.ok; cap.currentReadCode=reading.code
            if not reading.ok and cap.currentCodeLiveTested then cap.bindingStatus="PARTIAL"; cap.currentReadCode=reading.code.." / PREVIOUS_VERIFICATION_RETAINED" end
        end
        local positionAvailable=false
        for _,entity in ipairs(s.npcs) do if finite(entity.distance) and entity.position then positionAvailable=true; break end end
        local positionCap=self.BindingCapabilities.NPC_POSITION_READ; positionCap.currentAvailable=positionAvailable
        if not positionAvailable and positionCap.currentCodeLiveTested then positionCap.bindingStatus="PARTIAL" end
        self.Registry:refresh()
        local details={}
        for i,entity in ipairs(s.npcs) do
            if i>60 then break end
            local raw=a.lastEntities[entity.id]
            table.insert(details,{id=entity.id,npcConfig=a:getNpcConfig(raw),bossInfo=a:getBossInfo(raw),skills=a:getNpcSkills(raw),healthEvidence=a:getNpcHealth(raw),positionEvidence=a:getNpcPosition(raw)})
        end
        local report={version=self.Version,mode=self.ActionsEnabled and "CLIENT_LIVE" or "READ_ONLY",actionsEnabled=self.ActionsEnabled==true,character={ok=char.ok,code=char.code,evidence=char.evidence},player=s.player,entities=entities,entityDetails=details,entityDetailsTruncated=#s.npcs>60,skillSlots=slots,bossMarkers=markers,level=level,xp=xp,xpRequired=xpRequired,quest=quest,trackerCandidates=tracks,capabilities=self.BindingCapabilities,inspector=self:GetBindingInspector()}
        self.LastBindingReport=report
        return H.result(true,"READ_SCAN_COMPLETE",report)
    end)
end
function RAVYN:RunLiveReadScan()
    local r=self:RefreshReadBindings(); self:_showReport("BINDING REPORT",r); return r
end
function RAVYN:CaptureProbe(kind,label)
    local r=self.Probes:capture(kind,label); self:_showReport(kind.." "..label,r); return r
end
function RAVYN:CompareQuestState()
    local r=self.Probes:compareQuest(); self.LastQuestDiff=r
    self:_showReport("QUEST DIFF",{diff=r,before=self.Probes.captures.Quest.Before,after=self.Probes.captures.Quest.After})
    self.QuestDiffReport=self.ProbeReport; return r
end
function RAVYN:CompareCombat()
    local r=self.Probes:compareCombat(); self.LastCombatDiff=r
    self:_showReport("COMBAT DIFF",{diff=r,captures=self.Probes.captures.Combat})
    self.CombatDiffReport=self.ProbeReport; return r
end
function RAVYN:CopyProbeReport(kind)
    local textValue
    if kind=="Quest" then textValue=self.QuestDiffReport elseif kind=="Combat" then textValue=self.CombatDiffReport
    else textValue=self.LastBindingReport and ("RAVYN v3.4 | BINDING REPORT\n"..serialize(self.LastBindingReport)) end
    if not textValue then return result(false,"COMPARE_OR_SCAN_FIRST") end
    self.ProbeReport=textValue
    local copy=setclipboard or toclipboard
    if type(copy)~="function" then return result(false,"CLIPBOARD_UNAVAILABLE_USE_REPORT_BOX",textValue) end
    local ok,err=pcall(copy,textValue)
    return result(ok,ok and "REPORT_COPIED" or "CLIPBOARD_FAILED_USE_REPORT_BOX",ok and nil or tostring(err))
end
function RAVYN:_tick()
    if self.FSM.state~="RUNNING" then return end
    if os.clock()-(self._lastReadAt or -math.huge)<1 then return end
    self._lastReadAt=os.clock()
    local r=self:RefreshReadBindings()
    if not r.ok then self.Logger:log("WARN",r.code) end
end
-- Historical probe tick above is superseded by the v3.4 LiveClientActions loop below.
RAVYN.ProbeCapabilities=capabilitySpecs
Modules.ProbeFeatureReads=featureReads

CTX["Probe"]=Probe
CTX["H"]=H
CTX["serialize"]=serialize
CTX["questWords"]=questWords
CTX["combatWords"]=combatWords
CTX["matches"]=matches
CTX["reported"]=reported
CTX["capabilitySpecs"]=capabilitySpecs
CTX["featureReads"]=featureReads
CTX["actionNames"]=actionNames
CTX["registryRefresh"]=registryRefresh
return true]==========]); if not ok then return end end
do local ok=runChunk("SettingsPersistence.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Util=CTX["Util"]
local Config=CTX["Config"]
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local config=CTX["config"]
-- Executor-local settings persistence. No network access and no external loader.
local SETTINGS_FOLDER="RAVYN"
local SETTINGS_FILE=SETTINGS_FOLDER.."/Slayers2_settings_v3.json"
local function fileApi(name)
    local env=(getgenv and getgenv()) or _G
    local v=env and env[name]
    if type(v)=="function" then return v end
    local global=_G and _G[name]
    return type(global)=="function" and global or nil
end
local function jsonService()
    local ok,svc=pcall(function() return game:GetService("HttpService") end)
    return ok and svc or nil
end
function RAVYN:SaveSettings()
    if not (self.Config.UI and self.Config.UI.RememberSettings) then return result(false,"SETTINGS_PERSISTENCE_DISABLED") end
    local write=fileApi("writefile")
    if not write then return result(false,"WRITEFILE_UNAVAILABLE") end
    local mk=fileApi("makefolder")
    local folderExists=fileApi("isfolder")
    if mk and (not folderExists or not folderExists(SETTINGS_FOLDER)) then pcall(mk,SETTINGS_FOLDER) end
    local http=jsonService(); if not http then return result(false,"HTTP_SERVICE_UNAVAILABLE") end
    local ok,encoded=pcall(function() return http:JSONEncode(self.Config) end)
    if not ok then return result(false,"SETTINGS_ENCODE_FAILED",tostring(encoded)) end
    local saved,err=pcall(write,SETTINGS_FILE,encoded)
    if not saved then return result(false,"SETTINGS_WRITE_FAILED",tostring(err)) end
    return result(true,"SETTINGS_SAVED")
end
function RAVYN:LoadSettings()
    local read=fileApi("readfile"); local exists=fileApi("isfile")
    if not read or not exists or not exists(SETTINGS_FILE) then return result(false,"SETTINGS_NOT_FOUND") end
    local http=jsonService(); if not http then return result(false,"HTTP_SERVICE_UNAVAILABLE") end
    local ok,raw=pcall(read,SETTINGS_FILE); if not ok then return result(false,"SETTINGS_READ_FAILED",tostring(raw)) end
    local decodedOk,data=pcall(function() return http:JSONDecode(raw) end)
    if not decodedOk or type(data)~="table" then return result(false,"SETTINGS_DECODE_FAILED",tostring(data)) end
    local merged=Util.deepMerge(self.Config,data)
    local valid,errors=Config.validate(merged)
    if not valid then return result(false,"SETTINGS_INVALID",table.concat(errors,", ")) end
    self.Config=merged
    if self.Adapter then self.Adapter.config=merged.Diagnostic end
    if self.Registry then self.Registry.config=merged; self.Registry:refresh() end
    if self.Features and self.Features.registry then self.Features.registry.config=merged; self.Features.registry:refresh() end
    return result(true,"SETTINGS_LOADED")
end
function RAVYN:DeleteSavedSettings()
    local del=fileApi("delfile"); local exists=fileApi("isfile")
    if not del or not exists or not exists(SETTINGS_FILE) then return result(false,"SETTINGS_NOT_FOUND") end
    local ok,err=pcall(del,SETTINGS_FILE)
    return result(ok,ok and "SETTINGS_DELETED" or "SETTINGS_DELETE_FAILED",ok and nil or tostring(err))
end
local originalSetConfigForPersistence=RAVYN.SetConfig
function RAVYN:SetConfig(path,value)
    local r=originalSetConfigForPersistence(self,path,value)
    if r and r.ok and self.Config.UI and self.Config.UI.RememberSettings then
        task.defer(function() pcall(function() self:SaveSettings() end) end)
    end
    return r
end
CTX["SETTINGS_FOLDER"]=SETTINGS_FOLDER
CTX["SETTINGS_FILE"]=SETTINGS_FILE
CTX["fileApi"]=fileApi
CTX["jsonService"]=jsonService
CTX["originalSetConfigForPersistence"]=originalSetConfigForPersistence
return true]==========]); if not ok then return end end
do local ok=runChunk("LiveClientActions.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Util=CTX["Util"]
local Logger=CTX["Logger"]
local Config=CTX["Config"]
local FSM=CTX["FSM"]
local result=CTX["result"]
local finite=CTX["finite"]
local distance=CTX["distance"]
local FeatureRegistry=CTX["FeatureRegistry"]
local RAVYN=CTX["RAVYN"]
-- v3.5: smart client-side movement + local input dispatch.
-- No RemoteEvent/RemoteFunction binding is invented or called.
RAVYN.Version="3.6.1-smart"
RAVYN.Build="2026-09-26-v3.6.1-smart-live"
RAVYN.ProbeOnly=false
RAVYN.ActionsEnabled=true
RAVYN.ActionMode="SMART_CLIENT_INPUT"

Config.Default.SmartCombat={
    Enabled=true,
    Profile="Balanced",
    Positioning="Smart",
    LowHealthPercent=30,
    CriticalHealthPercent=20,
    RecoveryPercent=42,
    HealthSafetyEscape=false, -- OFF = never climb/retreat just because player HP dropped
    OrbitInterval=1.15,
    AdaptiveTravel=true,
    AutoFaceTarget=true,
}
if type(RAVYN.Config.SmartCombat)~="table" then
    RAVYN.Config.SmartCombat=Util.deepCopy(Config.Default.SmartCombat)
else
    RAVYN.Config.SmartCombat=Util.deepMerge(Config.Default.SmartCombat,RAVYN.Config.SmartCombat)
end

local validateV34=Config.validate
function Config.validate(c)
    local ok,errors=validateV34(c)
    local s=c.SmartCombat
    if type(s)~="table" then
        table.insert(errors,"SmartCombat")
    else
        local profiles={Safe=true,Balanced=true,Aggressive=true}
        local positions={Smart=true,Behind=true,Orbit=true,Above=true}
        if not profiles[s.Profile] then table.insert(errors,"SmartCombat.Profile") end
        if not positions[s.Positioning] then table.insert(errors,"SmartCombat.Positioning") end
        for _,k in ipairs({"LowHealthPercent","CriticalHealthPercent","RecoveryPercent","OrbitInterval"}) do
            if not finite(s[k]) or s[k]<0 then table.insert(errors,"SmartCombat."..k) end
        end
        if finite(s.CriticalHealthPercent) and finite(s.LowHealthPercent) and s.CriticalHealthPercent>s.LowHealthPercent then table.insert(errors,"SmartCombat health thresholds") end
        if finite(s.LowHealthPercent) and finite(s.RecoveryPercent) and s.RecoveryPercent<s.LowHealthPercent then table.insert(errors,"SmartCombat.RecoveryPercent") end
        if finite(s.RecoveryPercent) and s.RecoveryPercent>100 then table.insert(errors,"SmartCombat.RecoveryPercent") end
        if type(s.HealthSafetyEscape)~="boolean" then table.insert(errors,"SmartCombat.HealthSafetyEscape") end
    end
    return #errors==0,errors
end

local LiveAction={
    supported={
        NORMAL_MOB=true,BOSS=true,ATTACK=true,ABILITIES=true,SPEED=true,
        NPC_TELEPORT=true,YETI_FARM=true,YETI_TELEPORT=true,
    },
    lastAttack=0,lastSkill=0,lastScan=0,lastRetarget=0,lastOrbit=0,
    skillCursor=0,target=nil,targetId=nil,tween=nil,tweenTarget=nil,
    tweenDestination=nil,positionMode="IDLE",evading=false,
    lastInputSource=nil,lastMessage="READY",selectedTeleport=nil,
}
RAVYN.LiveAction=LiveAction

local PROFILE={
    Safe={attackDistance=8.5,rear=7.0,side=8.0,above=18,criticalAbove=26,skillDelay=1.75,attackCooldown=.60,longTeleport=360,tweenSpeed=185},
    Balanced={attackDistance=9.5,rear=6.0,side=7.0,above=16,criticalAbove=23,skillDelay=1.30,attackCooldown=.48,longTeleport=300,tweenSpeed=225},
    Aggressive={attackDistance=10.5,rear=5.0,side=6.0,above=13,criticalAbove=20,skillDelay=1.00,attackCooldown=.36,longTeleport=240,tweenSpeed=270},
}

local function liveService(name)
    local ok,v=pcall(function() return game:GetService(name) end)
    return ok and v or nil
end
local function liveRoot()
    local r=RAVYN.ReadAdapter:getRootPart()
    return r.ok and r.value or nil
end
local function liveHumanoid()
    local r=RAVYN.ReadAdapter:getHumanoid()
    return r.ok and r.value or nil
end
local function v3(v) return Vector3.new(v.x,v.y,v.z) end
local function safeSet(obj,key,value)
    local ok,err=pcall(function() obj[key]=value end)
    return ok,err
end
Hooks.activeProfile=function()
    return PROFILE[RAVYN.Config.SmartCombat.Profile] or PROFILE.Balanced
end
local function healthPercent()
    local s=RAVYN.Features.snapshot or {}
    local p=s.player or {}
    if finite(p.healthPercent) then return p.healthPercent end
    if finite(p.health) and finite(p.maxHealth) and p.maxHealth>0 then return (p.health/p.maxHealth)*100 end
    return 100
end

-- v1.2.2: every RAVYN physical-input primitive asks the InputAudit first (scope-checked; combat input only via LegacyCombatAdapter)
local function physicalGate(kind,detail)
    local A=RAVYN.InputAudit
    if not (A and A.physical) then return true end
    return A.physical(kind,detail)
end
Hooks.pressMouse1=function()
    -- Cursor-dependent executor click input is intentionally avoided. v3.8.2 later replaces
    -- this dispatcher with a fixed-screen input path before Boot executes.
    if not physicalGate("MOUSE","M1") then return false,"PHYSICAL_INPUT_BLOCKED" end
    local vu=liveService("VirtualUser")
    if vu then
        local ok=pcall(function()
            vu:CaptureController()
            local cam=workspace.CurrentCamera
            local cf=cam and cam.CFrame or CFrame.new()
            vu:Button1Down(Vector2.new(0,0),cf)
            task.wait(.025)
            vu:Button1Up(Vector2.new(0,0),cf)
        end)
        if ok then return true,"VirtualUser" end
    end
    local vim=liveService("VirtualInputManager")
    if vim then
        local ok=pcall(function()
            vim:SendMouseButtonEvent(0,0,0,true,game,0)
            task.wait(.025)
            vim:SendMouseButtonEvent(0,0,0,false,game,0)
        end)
        if ok then return true,"VirtualInputManager" end
    end
    return false,"INPUT_UNAVAILABLE"
end

local function keyCodeFromText(text)
    if type(text)~="string" or text=="" then return nil end
    local clean=string.upper(string.gsub(text,"%s+",""))
    local ok,val=pcall(function() return Enum.KeyCode[clean] end)
    return ok and val or nil
end
local function pressKey(text)
    local key=keyCodeFromText(text)
    if not key then return false,"KEY_UNMAPPED:"..tostring(text) end
    if not physicalGate("KEY",text) then return false,"PHYSICAL_INPUT_BLOCKED" end
    local vim=liveService("VirtualInputManager")
    if vim then
        local ok=pcall(function()
            vim:SendKeyEvent(true,key,false,game)
            task.wait(.03)
            vim:SendKeyEvent(false,key,false,game)
        end)
        if ok then return true,"VirtualInputManager" end
    end
    local env=(getgenv and getgenv()) or _G
    if type(env.keypress)=="function" and type(env.keyrelease)=="function" then
        local ok=pcall(function()
            env.keypress(key.Value)
            task.wait(.03)
            env.keyrelease(key.Value)
        end)
        if ok then return true,"keypress" end
    end
    return false,"INPUT_UNAVAILABLE"
end

local function rawTargetRoot(target)
    if not target or not target.id then return nil end
    local raw=RAVYN.ReadAdapter.lastEntities and RAVYN.ReadAdapter.lastEntities[target.id]
    if not raw then return nil end
    local ok,root=pcall(function() return RAVYN.ReadAdapter:_entityRoot(raw) end)
    if ok then return root end
    return nil
end

local function targetBasis(target)
    local p=target and target.position and v3(target.position) or nil
    local look=Vector3.new(0,0,-1)
    local right=Vector3.new(1,0,0)
    local tr=rawTargetRoot(target)
    if tr then
        local ok,cf=pcall(function() return tr.CFrame end)
        if ok and cf then
            p=cf.Position
            look=cf.LookVector
            right=cf.RightVector
        end
    end
    return p,look,right
end

local function groundSafe(candidate,ignoreA,ignoreB)
    local ws=liveService("Workspace")
    if not ws or not ws.Raycast then return candidate end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    local filter={}
    if ignoreA then table.insert(filter,ignoreA) end
    if ignoreB then table.insert(filter,ignoreB) end
    params.FilterDescendantsInstances=filter
    local origin=candidate+Vector3.new(0,7,0)
    local hit=ws:Raycast(origin,Vector3.new(0,-20,0),params)
    if hit and candidate.Y<hit.Position.Y+2.6 then
        return Vector3.new(candidate.X,hit.Position.Y+2.6,candidate.Z)
    end
    return candidate
end

Hooks.smartDestination=function(target,now)
    local p,look,right=targetBasis(target)
    if not p then return nil,"NO_TARGET_POSITION" end
    local profile=Hooks.activeProfile()
    local smart=RAVYN.Config.SmartCombat
    local hp=healthPercent()

    if smart.HealthSafetyEscape then
        if hp<=smart.CriticalHealthPercent then LiveAction.evading=true end
        if not LiveAction.evading and hp<=smart.LowHealthPercent then LiveAction.evading=true end
        if LiveAction.evading and hp>=smart.RecoveryPercent then LiveAction.evading=false end
    else
        -- User-controlled combat stance: HP alone must never raise/retreat the player.
        LiveAction.evading=false
    end

    if LiveAction.evading then
        local h=hp<=smart.CriticalHealthPercent and profile.criticalAbove or profile.above
        LiveAction.positionMode=hp<=smart.CriticalHealthPercent and "CRITICAL EVADE" or "SAFE EVADE"
        return p+Vector3.new(0,h,0),LiveAction.positionMode
    end

    local forced=smart.Positioning
    local phase=math.floor(now/math.max(.45,smart.OrbitInterval))%4
    local mode=forced
    if forced=="Smart" then
        if phase==0 then mode="Behind"
        elseif phase==1 then mode="OrbitRight"
        elseif phase==2 then mode="LowFlank"
        else mode="OrbitLeft" end
    elseif forced=="Orbit" then
        mode=(phase%2==0) and "OrbitRight" or "OrbitLeft"
    end

    local dest
    if mode=="Above" then
        dest=p+Vector3.new(0,profile.above*.70,0)
        LiveAction.positionMode="ABOVE"
    elseif mode=="OrbitRight" then
        dest=p+(right*profile.side)-(look*2.2)+Vector3.new(0,1.8,0)
        LiveAction.positionMode="RIGHT FLANK"
    elseif mode=="OrbitLeft" then
        dest=p-(right*profile.side)-(look*2.2)+Vector3.new(0,1.8,0)
        LiveAction.positionMode="LEFT FLANK"
    elseif mode=="LowFlank" then
        dest=p-(look*(profile.rear*.72))+(right*(profile.side*.35))+Vector3.new(0,-1.4,0)
        LiveAction.positionMode="LOW FLANK"
    else
        dest=p-(look*profile.rear)+Vector3.new(0,1.5,0)
        LiveAction.positionMode="BEHIND"
    end

    local character=RAVYN.ReadAdapter:getCharacter()
    local targetRaw=RAVYN.ReadAdapter.lastEntities and RAVYN.ReadAdapter.lastEntities[target.id]
    dest=groundSafe(dest,character.ok and character.value or nil,targetRaw)
    return dest,LiveAction.positionMode
end

local function cancelTween()
    if LiveAction.tween then pcall(function() LiveAction.tween:Cancel() end) end
    LiveAction.tween=nil
    LiveAction.tweenTarget=nil
    LiveAction.tweenDestination=nil
end

local function faceTarget(root,targetPos)
    if not RAVYN.Config.SmartCombat.AutoFaceTarget then return end
    if not root or not targetPos then return end
    pcall(function()
        local here=root.Position
        local flat=Vector3.new(targetPos.X,here.Y,targetPos.Z)
        if (flat-here).Magnitude>.15 then root.CFrame=CFrame.lookAt(here,flat) end
    end)
end

local function moveSmart(target,instant)
    local root=liveRoot()
    if not root or not target or not target.position then return result(false,"ROOT_OR_TARGET_UNAVAILABLE") end
    -- v3.8.4: single movement owner. TRAVEL / COMBAT_HOVER / RECOVERY are owned by the
    -- TravelController and CombatMobility; legacy moveSmart only runs for IDLE, DEFENSE
    -- (dodge side-steps) or an explicit manual bypass (NPC teleport).
    local MO=RAVYN.MoveOwner
    if MO and not MO.bypass and (MO.current=="TRAVEL" or MO.current=="COMBAT_HOVER" or MO.current=="RECOVERY") then
        return result(true,"OWNED_BY_"..MO.current)
    end
    -- v1.1 single movement authority: while the TravelController runs, a freshly acquired target (owner still IDLE for
    -- one ownership step) is travelled to by the TravelController, never by this legacy teleport as well.
    local tcv=RAVYN.Config.TravelController
    if MO and not MO.bypass and MO.current=="IDLE" and tcv and tcv.Enabled and RAVYN.FSM and RAVYN.FSM.state=="RUNNING" then
        return result(true,"DEFERRED_TO_TRAVEL_CONTROLLER")
    end
    local now=os.clock()
    local dest,positionMode=Hooks.smartDestination(target,now)
    if not dest then return result(false,positionMode or "DESTINATION_UNAVAILABLE") end
    local targetPos=targetBasis(target)
    local dist=(root.Position-dest).Magnitude
    local profile=Hooks.activeProfile()

    local useTeleport=instant or RAVYN.Config.Movement.TravelMode=="Teleport" or (RAVYN.Config.TravelController and RAVYN.Config.TravelController.TeleportOnly==true)
    local cm2=RAVYN.Config and RAVYN.Config.CombatMobility
    if not (RAVYN.Config.TravelController and RAVYN.Config.TravelController.TeleportOnly==true) and cm2 and cm2.Enabled and cm2.NoCombatTeleport and LiveAction.target then useTeleport=false
    elseif RAVYN.Config.SmartCombat.AdaptiveTravel and dist>=profile.longTeleport then useTeleport=true end
    if useTeleport then
        cancelTween()
        local cf=CFrame.lookAt(dest,targetPos)
        local ok,err=safeSet(root,"CFrame",cf)
        if ok then
            LiveAction.lastMessage="TELEPORTED · "..positionMode
            return result(true,"TELEPORTED",{position=positionMode})
        end
        return result(false,"TELEPORT_FAILED",tostring(err))
    end

    if dist<1.35 then
        cancelTween()
        faceTarget(root,targetPos)
        return result(true,"SMART_POSITION_HELD",{position=positionMode})
    end

    local targetMoved=true
    if LiveAction.tweenDestination then
        targetMoved=(LiveAction.tweenDestination-dest).Magnitude>2.4
    end
    if LiveAction.tweenTarget==target.id and LiveAction.tween and not targetMoved then
        return result(true,"TWEEN_ACTIVE",{position=positionMode})
    end

    cancelTween()
    local ts=liveService("TweenService")
    if not ts then return result(false,"TWEEN_SERVICE_UNAVAILABLE") end
    local speed=RAVYN.Config.SmartCombat.Enabled and profile.tweenSpeed or math.max(25,tonumber(RAVYN.Config.Movement.TweenSpeed) or 150)
    local duration=math.max(.055,dist/speed)
    local cf=CFrame.lookAt(dest,targetPos)
    local tween=ts:Create(root,TweenInfo.new(duration,Enum.EasingStyle.Linear,Enum.EasingDirection.Out),{CFrame=cf})
    LiveAction.tween=tween
    LiveAction.tweenTarget=target.id
    LiveAction.tweenDestination=dest
    tween:Play()
    return result(true,"SMART_TWEEN_STARTED",{position=positionMode})
end

local function matchesTarget(e,cfg)
    local wanted=string.lower(tostring(cfg.TargetName or "Any"))
    if wanted=="" or wanted=="any" or wanted=="nearest" then return true end
    local name=string.lower(tostring(e.name or ""))
    return name==wanted or string.find(name,wanted,1,true)~=nil
end

local function findSnapshotTarget(id)
    if not id then return nil end
    for _,e in ipairs((RAVYN.Features.snapshot or {}).npcs or {}) do
        if e.id==id then return e end
    end
    return nil
end

local function selectTarget(kind,allowMove)
    local s=RAVYN.Features.snapshot or {}
    local player=s.player or {}
    if not player.position then return nil end
    local cfg=(kind=="BOSS") and RAVYN.Config.Farm.Boss or RAVYN.Config.Farm.NormalMobs
    local unlimited=allowMove and RAVYN.Config.TravelController and RAVYN.Config.TravelController.UnlimitedRange
    local maxDistance=unlimited and math.huge or (allowMove and math.min(cfg.MaxDistance,cfg.TargetRadius) or math.max(22,Hooks.activeProfile().attackDistance*1.75))

    local sticky=findSnapshotTarget(LiveAction.targetId)
    if sticky then
        local isBoss=sticky.isBoss==true or sticky.classification=="BOSS"
        local validKind=(kind=="BOSS" and isBoss) or (kind=="MOB" and not isBoss)
        local d=sticky.position and distance(player.position,sticky.position) or nil
        if validKind and matchesTarget(sticky,cfg) and sticky.alive~=false and sticky.health and sticky.health>0 and d and d<=maxDistance*1.35 then
            local copy=Util.deepCopy(sticky)
            copy.distance=d
            return copy
        end
    end

    local best,bestScore=nil,math.huge
    for _,e in ipairs(s.npcs or {}) do
        local isBoss=e.isBoss==true or e.classification=="BOSS"
        local eligible=(kind=="BOSS" and isBoss) or (kind=="MOB" and not isBoss)
        if eligible and matchesTarget(e,cfg) and e.alive~=false and e.position and e.health and e.health>0 then
            local d=distance(player.position,e.position)
            if d and d<=maxDistance then
                local score=d
                if e.maxHealth and e.maxHealth>0 then
                    local hpRatio=e.health/e.maxHealth
                    score=score-(1-hpRatio)*6
                end
                if score<bestScore then best,bestScore=e,score end
            end
        end
    end
    if best then
        best=Util.deepCopy(best)
        best.distance=distance(player.position,best.position)
    end
    return best
end

local function currentSkillKeys()
    local r=RAVYN.ReadAdapter:getSkillSlots()
    if not r.ok then return {} end
    local keys={}
    for _,slot in ipairs(r.value or {}) do
        if slot.visible~=false then
            for _,k in ipairs(slot.keybindCandidates or {}) do
                if keyCodeFromText(k.text) then
                    table.insert(keys,{index=slot.index,key=string.upper((string.gsub(k.text,"%s+",""))),path=slot.path,keyPath=k.path,source=k.source or "EXPLICIT_NAME"})
                    break
                end
            end
        end
    end
    table.sort(keys,function(a,b) return a.index<b.index end)
    return keys
end

function RAVYN:GetObservedNPCs(kind,limit,query)
    local out={}
    local q=string.lower(tostring(query or ""))
    for _,e in ipairs((self.Features.snapshot or {}).npcs or {}) do
        local isBoss=e.isBoss==true or e.classification=="BOSS"
        local kindOk=(not kind) or kind=="ALL" or (kind=="BOSS" and isBoss) or (kind=="MOB" and not isBoss)
        local name=string.lower(tostring(e.name or ""))
        if kindOk and e.position and e.alive~=false and (q=="" or string.find(name,q,1,true)) then
            table.insert(out,{name=e.name,id=e.id,distance=e.distance or math.huge,isBoss=isBoss,health=e.health,maxHealth=e.maxHealth})
        end
    end
    table.sort(out,function(a,b)
        if a.distance==b.distance then return tostring(a.name)<tostring(b.name) end
        return a.distance<b.distance
    end)
    local n=math.min(limit or 8,#out)
    local trimmed={}
    local seen={}
    for i=1,n do
        local x=out[i]
        if not seen[x.name] then table.insert(trimmed,x); seen[x.name]=true end
    end
    return trimmed
end

function RAVYN:ClientAttack()
    local B=RAVYN.CombatActionBus
    if not B then return result(false,"COMBAT_BUS_UNAVAILABLE") end
    local r=B:RequestAttack(LiveAction.target,{source="ClientAttack"})
    LiveAction.lastInputSource=(r.value and r.value.backend) or r.code
    return r
end

function RAVYN:ClientSkill()
    local keys=currentSkillKeys()
    if #keys==0 then return result(false,"NO_VISIBLE_SKILL_KEYS") end
    LiveAction.skillCursor=(LiveAction.skillCursor%#keys)+1
    local chosen=keys[LiveAction.skillCursor]
    -- v1.2.2: the hotbar key is only an identifier; the CombatActionBus decides silent / legacy / nothing
    local B=RAVYN.CombatActionBus
    if not B then return result(false,"COMBAT_BUS_UNAVAILABLE") end
    local r=B:RequestSkill(chosen,LiveAction.target,{source="ClientSkill"})
    LiveAction.lastInputSource=(r.value and r.value.backend) or r.code
    return r
end

function RAVYN:TeleportToNPC(query)
    if self.FSM.state~="RUNNING" then
        local start=self:Start()
        if not start.ok and start.code~="ALREADY_RUNNING" then return start end
    end
    self:RefreshReadBindings()
    local q=string.lower(tostring(query or ""))
    local best=nil
    for _,e in ipairs(self.Features.snapshot.npcs or {}) do
        local name=string.lower(tostring(e.name or ""))
        local id=string.lower(tostring(e.id or ""))
        if e.position and e.alive~=false and (q=="" or q=="nearest" or string.find(name,q,1,true) or string.find(id,q,1,true)) then
            if not best or (e.distance or math.huge)<(best.distance or math.huge) then best=e end
        end
    end
    if not best then return result(false,"NPC_NOT_FOUND") end
    local old=LiveAction.evading
    LiveAction.evading=false
    local r=moveSmart(best,true)
    LiveAction.evading=old
    if r.ok then
        self.LiveAction.target=best
        self.LiveAction.targetId=best.id
        self.LiveAction.selectedTeleport=best.name
    end
    return r
end

function RAVYN:SetSmartProfile(name)
    if not PROFILE[name] then return result(false,"UNKNOWN_PROFILE") end
    return self:SetConfig("SmartCombat.Profile",name)
end
function RAVYN:SetSmartPosition(name)
    local allowed={Smart=true,Behind=true,Orbit=true,Above=true}
    if not allowed[name] then return result(false,"UNKNOWN_POSITION_MODE") end
    return self:SetConfig("SmartCombat.Positioning",name)
end
function RAVYN:SetFarmTarget(name,boss)
    local path=boss and "Farm.Boss.TargetName" or "Farm.NormalMobs.TargetName"
    return self:SetConfig(path,(name==nil or name=="") and "Any" or name)
end

function RAVYN:SetFeature(id,enabled)
    local f=self.Registry.items[id]
    if not f then return result(false,"UNKNOWN_FEATURE") end
    if type(enabled)~="boolean" then return result(false,"INVALID_CONFIG") end
    if enabled and not LiveAction.supported[id] then
        return result(false,"BINDING_REQUIRED",{feature=f.name,binding=f.bindingStatus})
    end
    if enabled and id=="NORMAL_MOB" and self.Config.Farm.Boss.Enabled then
        self:SetConfig("Farm.Boss.Enabled",false)
    elseif enabled and id=="BOSS" and self.Config.Farm.NormalMobs.Enabled then
        self:SetConfig("Farm.NormalMobs.Enabled",false)
    end
    local r=self:SetConfig(f.path,enabled)
    if not r.ok then return r end
    if enabled and self.FSM.state=="STOPPED" then
        local sr=self:Start()
        if not sr.ok and sr.code~="ALREADY_RUNNING" then return sr end
    end
    if not enabled and (id=="NORMAL_MOB" or id=="BOSS") then
        cancelTween()
        LiveAction.target=nil
        LiveAction.targetId=nil
        LiveAction.evading=false
    end
    return result(true,enabled and "ENABLED_LIVE" or "DISABLED")
end

local oldRegistryRefresh=FeatureRegistry.refresh
function FeatureRegistry:refresh()
    oldRegistryRefresh(self)
    if not RAVYN or not RAVYN.LiveAction then return end
    for _,f in ipairs(self.order) do
        if LiveAction.supported[f.id] then
            f.bindingStatus="CLIENT_LIVE"
            f.liveTested=true
            f.available=f.enabled and f.premiumAllowed
            f.status=f.enabled and "ACTIVE" or "READY"
            f.note="Verified local movement/input path. No game remotes used."
        else
            f.available=false
            f.status=f.enabled and "BLOCKED · BINDING REQUIRED" or "LOCKED"
            f.note="Hidden from quick controls until its exact action binding is verified."
        end
    end
end

function RAVYN:GetFeatureActionStatus(id)
    local f=self.Registry.items[id]
    if not f then return "UNKNOWN" end
    return LiveAction.supported[id] and "LIVE" or "NEEDS BINDING"
end

local function liveStep()
    local now=os.clock()
    if now-(LiveAction.lastScan or 0)>=.35 then
        LiveAction.lastScan=now
        local rr=RAVYN:RefreshReadBindings()
        if not rr.ok then return rr end
    end

    local humanoid=liveHumanoid()
    if RAVYN.Config.Movement.SpeedEnabled and humanoid then
        pcall(function() humanoid.WalkSpeed=RAVYN.Config.Movement.Speed end)
    end

    local farmMode=nil
    if RAVYN.Config.Farm.Boss.Enabled then farmMode="BOSS"
    elseif RAVYN.Config.Farm.NormalMobs.Enabled then farmMode="MOB" end

    local combatOnly=(not farmMode) and (RAVYN.Config.Combat.AutoAttack or RAVYN.Config.Combat.AutoAbilities)
    local mode=farmMode or (combatOnly and "MOB" or nil)
    local target=mode and selectTarget(mode,farmMode~=nil) or nil

    LiveAction.target=target
    LiveAction.targetId=target and target.id or nil
    RAVYN.Features.currentTarget=target

    if not target then
        cancelTween()
        LiveAction.positionMode="IDLE"
        return result(true,"LIVE_IDLE")
    end

    local profile=Hooks.activeProfile()
    local hp=healthPercent()
    local allowMovement=farmMode~=nil
    if allowMovement then
        local mr=moveSmart(target,false)
        LiveAction.lastMessage=mr.code
    else
        local root=liveRoot()
        local tpos=targetBasis(target)
        faceTarget(root,tpos)
    end

    local d=target.distance or math.huge
    local inAttackRange=d<=math.max(profile.attackDistance,12)
    local evading=LiveAction.evading

    if inAttackRange or allowMovement then
        if RAVYN.Config.Combat.AutoAttack and not evading and d<=profile.attackDistance and now-LiveAction.lastAttack>=profile.attackCooldown then
            LiveAction.lastAttack=now
            RAVYN:ClientAttack()
        end
        if RAVYN.Config.Combat.AutoAbilities and d<=math.max(profile.attackDistance+7,16) and now-LiveAction.lastSkill>=profile.skillDelay then
            LiveAction.lastSkill=now
            RAVYN:ClientSkill()
        end
    end

    if evading then
        LiveAction.lastMessage=string.format("EVADE · %.0f%% HP · %s",hp,LiveAction.positionMode)
    else
        LiveAction.lastMessage=LiveAction.positionMode.." · "..tostring(target.name)
    end
    return result(true,"SMART_LIVE_TICK")
end

function RAVYN:_tick()
    if self.FSM.state~="RUNNING" then return end
    local r=Util.safeCall(liveStep)
    if not r.ok then
        self.Telemetry.actionsFailed=self.Telemetry.actionsFailed+1
        self.Features.lastError=r.message
        self.Logger:log("ERROR",r.message)
    end
end

local baseStopV35=RAVYN.Stop
function RAVYN:Stop()
    cancelTween()
    LiveAction.target=nil
    LiveAction.targetId=nil
    LiveAction.evading=false
    LiveAction.positionMode="IDLE"
    return baseStopV35(self)
end

RAVYN.Registry:refresh()
CTX["validateV34"]=validateV34
CTX["LiveAction"]=LiveAction
CTX["PROFILE"]=PROFILE
CTX["liveService"]=liveService
CTX["liveRoot"]=liveRoot
CTX["liveHumanoid"]=liveHumanoid
CTX["v3"]=v3
CTX["safeSet"]=safeSet
CTX["healthPercent"]=healthPercent
CTX["keyCodeFromText"]=keyCodeFromText
CTX["physicalGate"]=physicalGate
CTX["pressKey"]=pressKey
CTX["rawTargetRoot"]=rawTargetRoot
CTX["targetBasis"]=targetBasis
CTX["groundSafe"]=groundSafe
CTX["cancelTween"]=cancelTween
CTX["faceTarget"]=faceTarget
CTX["moveSmart"]=moveSmart
CTX["matchesTarget"]=matchesTarget
CTX["findSnapshotTarget"]=findSnapshotTarget
CTX["selectTarget"]=selectTarget
CTX["currentSkillKeys"]=currentSkillKeys
CTX["oldRegistryRefresh"]=oldRegistryRefresh
CTX["liveStep"]=liveStep
CTX["baseStopV35"]=baseStopV35
return true]==========]); if not ok then return end end
do local ok=runChunk("CombatIntelligenceV37.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Util=CTX["Util"]
local Logger=CTX["Logger"]
local Config=CTX["Config"]
local FSM=CTX["FSM"]
local result=CTX["result"]
local pos=CTX["pos"]
local distance=CTX["distance"]
local RAVYN=CTX["RAVYN"]
local Probe=CTX["Probe"]
local fileApi=CTX["fileApi"]
local LiveAction=CTX["LiveAction"]
local liveService=CTX["liveService"]
local liveRoot=CTX["liveRoot"]
local liveHumanoid=CTX["liveHumanoid"]
local v3=CTX["v3"]
local safeSet=CTX["safeSet"]
local healthPercent=CTX["healthPercent"]
local targetBasis=CTX["targetBasis"]
local cancelTween=CTX["cancelTween"]
local faceTarget=CTX["faceTarget"]
local moveSmart=CTX["moveSmart"]
local matchesTarget=CTX["matchesTarget"]
local findSnapshotTarget=CTX["findSnapshotTarget"]
local currentSkillKeys=CTX["currentSkillKeys"]
-- v3.7 intelligence layer. Extends v3.6.1 without guessing server bindings.
RAVYN.Version="3.7.0-intelligence"
RAVYN.Build="2026-09-26-v3.7-combat-intelligence"

Config.Default.Intelligence={
    AutoPlay=false,
    SearchRadius="Normal",
    KillAura={Enabled=false,Follow=true,Range="Normal"},
    AntiAFK=true,
    ESP={NPC=false,Boss=false,Range="Normal"},
    TargetRules={SkipCivilians=true,MaxMobHP=0,RiskMode="Balanced",SkipBossTooStrong=true,NeverAttack={}},
    CombatBrain={Enabled=true,SmartCombo=true,AttackRange="Normal",SkillTempo="Normal",Distance="Normal",TravelSpeed="Normal",RepositionInterval=1.15,DamageRisk=true},
    SavedPlaces={},
}
RAVYN.Config.Intelligence=Util.deepMerge(Config.Default.Intelligence,RAVYN.Config.Intelligence or {})

local validateV37Base=Config.validate
function Config.validate(c)
    local ok,errors=validateV37Base(c)
    local i=c.Intelligence
    if type(i)~="table" then
        table.insert(errors,"Intelligence")
    else
        local radius={Near=true,Normal=true,Wide=true,Stream=true}
        local risk={Safe=true,Balanced=true,Any=true}
        local range={Close=true,Normal=true,Wide=true}
        local tempo={Careful=true,Normal=true,Fast=true}
        local dist={Close=true,Normal=true,Safe=true}
        if not radius[i.SearchRadius] then table.insert(errors,"Intelligence.SearchRadius") end
        if type(i.KillAura)~="table" or not range[i.KillAura.Range] then table.insert(errors,"Intelligence.KillAura") end
        if type(i.ESP)~="table" or not radius[i.ESP.Range] then table.insert(errors,"Intelligence.ESP") end
        if type(i.TargetRules)~="table" or not risk[i.TargetRules.RiskMode] or type(i.TargetRules.NeverAttack)~="table" then table.insert(errors,"Intelligence.TargetRules") end
        if type(i.CombatBrain)~="table" or not range[i.CombatBrain.AttackRange] or not tempo[i.CombatBrain.SkillTempo] or not dist[i.CombatBrain.Distance] or not tempo[i.CombatBrain.TravelSpeed] then table.insert(errors,"Intelligence.CombatBrain") end
        if type(i.SavedPlaces)~="table" then table.insert(errors,"Intelligence.SavedPlaces") end
    end
    return #errors==0,errors
end

local Brain={
    state="IDLE",stateSince=os.clock(),previousTargetId=nil,lastHealth=nil,lastHealthAt=nil,
    damagePerSecond=0,riskScore=0,forceEvade=false,lastSafeAt=os.clock(),lastReposition=0,
    bossMemory={},recentTargets={},combo={m1=0,stage=1,lastSkillKey=nil,lastSkillAt={},lastAction="—"},
    esp={items={},container=nil,lastRefresh=0},afkConnection=nil,lastTargetLostAt=0,
}
RAVYN.Brain=Brain

local RADIUS_MAP={Near=80,Normal=250,Wide=500,Stream=math.huge}
local AURA_MAP={Close=18,Normal=45,Wide=90}
local ATTACK_RANGE_MAP={Close=.78,Normal=1.0,Wide=1.28}
local SKILL_TEMPO_MAP={Careful=1.38,Normal=1.0,Fast=.72}
local DISTANCE_MAP={Close=.78,Normal=1.0,Safe=1.30}
local TRAVEL_SPEED_MAP={Careful=.80,Normal=1.0,Fast=1.30}

local function setBrainState(s)
    if Brain.state~=s then Brain.state=s; Brain.stateSince=os.clock() end
end
local function listContainsInsensitive(list,value)
    local needle=string.lower(tostring(value or ""))
    for _,x in ipairs(list or {}) do if string.lower(tostring(x))==needle then return true end end
    return false
end

local baseActiveProfileV37=Hooks.activeProfile
Hooks.activeProfile=function()
    local p=Util.deepCopy(baseActiveProfileV37())
    local c=RAVYN.Config.Intelligence and RAVYN.Config.Intelligence.CombatBrain or {}
    p.attackDistance=p.attackDistance*(ATTACK_RANGE_MAP[c.AttackRange] or 1)
    p.rear=p.rear*(DISTANCE_MAP[c.Distance] or 1)
    p.side=p.side*(DISTANCE_MAP[c.Distance] or 1)
    p.skillDelay=p.skillDelay*(SKILL_TEMPO_MAP[c.SkillTempo] or 1)
    p.tweenSpeed=p.tweenSpeed*(TRAVEL_SPEED_MAP[c.TravelSpeed] or 1)
    return p
end

local function playerSnapshot() return (RAVYN.Features.snapshot or {}).player or {} end
local function updateDamageRisk(now)
    local p=playerSnapshot(); local hp=tonumber(p.health); local maxHp=tonumber(p.maxHealth)
    if not hp or not maxHp or maxHp<=0 then Brain.damagePerSecond=0; Brain.riskScore=0; return end
    if Brain.lastHealth and Brain.lastHealthAt and now>Brain.lastHealthAt then
        local dt=math.max(.05,now-Brain.lastHealthAt); local loss=math.max(0,Brain.lastHealth-hp); local instant=loss/dt
        Brain.damagePerSecond=(Brain.damagePerSecond*.68)+(instant*.32)
    end
    Brain.lastHealth=hp; Brain.lastHealthAt=now
    local hpPct=(hp/maxHp)*100; local dpsPct=(Brain.damagePerSecond/maxHp)*100
    Brain.riskScore=math.min(100,math.max(0,100-hpPct)*.58+math.min(100,dpsPct*6.5)*.72)
    local sc=RAVYN.Config.SmartCombat; local damageRisk=RAVYN.Config.Intelligence.CombatBrain.DamageRisk
    if sc.HealthSafetyEscape==false then
        Brain.forceEvade=false; Brain.emergency384=false; LiveAction.evading=false
        return
    end
    local danger=(hpPct<=sc.LowHealthPercent) or (damageRisk and hpPct<68 and Brain.riskScore>=58)
    local critical=hpPct<=sc.CriticalHealthPercent or (damageRisk and hpPct<48 and Brain.riskScore>=82)
    local cm=RAVYN.Config and RAVYN.Config.CombatMobility
    -- v3.8.4: KeepComboUnderHit keeps combo through normal damage but never disables survival.
    -- Critical HP (or an active emergency evade not yet recovered) always wins.
    local emergencyHeld=Brain.forceEvade and Brain.emergency384 and hpPct<sc.RecoveryPercent
    if cm and cm.Enabled and cm.KeepComboUnderHit and not critical and not emergencyHeld then
        Brain.forceEvade=false; Brain.emergency384=false
    elseif critical or danger then Brain.forceEvade=true; if critical then Brain.emergency384=true end
    elseif Brain.forceEvade and hpPct>=sc.RecoveryPercent and dpsPct<1.2 then Brain.forceEvade=false; Brain.emergency384=false; Brain.lastSafeAt=now end
end

local baseSmartDestinationV37=Hooks.smartDestination
Hooks.smartDestination=function(target,now)
    if Brain.forceEvade and target and target.position then
        local p=targetBasis(target)
        if p then
            local profile=Hooks.activeProfile(); local hp=healthPercent()
            local h=(hp<=RAVYN.Config.SmartCombat.CriticalHealthPercent or Brain.riskScore>=82) and profile.criticalAbove or profile.above
            LiveAction.evading=true; LiveAction.positionMode=(h==profile.criticalAbove) and "CRITICAL EVADE" or "RISK EVADE"
            return p+Vector3.new(0,h,0),LiveAction.positionMode
        end
    end
    if LiveAction.evading and not Brain.forceEvade and healthPercent()>=RAVYN.Config.SmartCombat.RecoveryPercent then LiveAction.evading=false end
    return baseSmartDestinationV37(target,now)
end

local function localRiskRating(e)
    local p=playerSnapshot(); local targetMax=tonumber(e and e.maxHealth); local myMax=tonumber(p.maxHealth)
    if not targetMax or not myMax or myMax<=0 then return "UNKNOWN",1 end
    local ratio=targetMax/myMax
    if ratio<=1.6 then return "SAFE",ratio end
    if ratio<=4.5 then return "RISKY",ratio end
    return "TOO_STRONG",ratio
end
function RAVYN:GetRiskRating(e) return localRiskRating(e) end

local function targetAllowed(e,kind)
    if not e or e.alive==false or not e.position or not e.health or e.health<=0 then return false,"DEAD_OR_INVALID" end
    local rules=RAVYN.Config.Intelligence.TargetRules; local class=tostring(e.classification or "UNKNOWN")
    if rules.SkipCivilians and (class=="PLAYER" or class=="TRAINER" or class=="QUEST_NPC" or class=="MERCHANT") then return false,"CIVILIAN" end
    if listContainsInsensitive(rules.NeverAttack,e.name) then return false,"NEVER_ATTACK" end
    if kind=="MOB" and tonumber(rules.MaxMobHP or 0)>0 and tonumber(e.maxHealth or e.health or 0)>rules.MaxMobHP then return false,"MAX_HP" end
    local rating=localRiskRating(e)
    if rules.RiskMode=="Safe" and rating~="SAFE" then return false,"RISK_FILTER" end
    if rules.RiskMode=="Balanced" and rating=="TOO_STRONG" then return false,"RISK_FILTER" end
    if kind=="BOSS" and rules.SkipBossTooStrong and rating=="TOO_STRONG" then return false,"BOSS_TOO_STRONG" end
    return true
end

local function updateBossMemory(now)
    local seen={}
    for _,e in ipairs((RAVYN.Features.snapshot or {}).npcs or {}) do
        if e.isBoss==true or e.classification=="BOSS" then
            local id=e.id; local m=Brain.bossMemory[id] or {id=id,name=e.name,seenCount=0}
            m.name=e.name; m.lastSeen=now; m.seenCount=(m.seenCount or 0)+1; m.lastHealth=e.health; m.lastMaxHealth=e.maxHealth; m.alive=e.alive~=false and (e.health or 0)>0; m.distance=e.distance
            if not m.alive and m.wasAlive then m.lastDownAt=now end
            m.wasAlive=m.alive; Brain.bossMemory[id]=m; seen[id]=true
        end
    end
    for id,m in pairs(Brain.bossMemory) do if not seen[id] and m.wasAlive then m.lastUnavailableAt=now; m.wasAlive=false; m.alive=false end end
end

local function smartSearchRadius() return RADIUS_MAP[RAVYN.Config.Intelligence.SearchRadius] or 250 end
local function selectBrainTarget(kind,allowMove)
    local s=RAVYN.Features.snapshot or {}; local p=s.player or {}; if not p.position then return nil end
    local cfg=(kind=="BOSS") and RAVYN.Config.Farm.Boss or RAVYN.Config.Farm.NormalMobs
    local unlimited=allowMove and RAVYN.Config.TravelController and RAVYN.Config.TravelController.UnlimitedRange
    local maxDistance=unlimited and math.huge or (allowMove and math.min(cfg.MaxDistance or math.huge,cfg.TargetRadius or math.huge,smartSearchRadius()) or math.max(22,Hooks.activeProfile().attackDistance*1.75))
    local sticky=findSnapshotTarget(LiveAction.targetId)
    if sticky then
        local isBoss=sticky.isBoss==true or sticky.classification=="BOSS"; local kindOk=(kind=="BOSS" and isBoss) or (kind=="MOB" and not isBoss)
        local okAllowed=targetAllowed(sticky,kind); local d=sticky.position and distance(p.position,sticky.position) or nil
        if kindOk and okAllowed and matchesTarget(sticky,cfg) and d and d<=maxDistance*1.35 then local copy=Util.deepCopy(sticky); copy.distance=d; return copy end
    end
    local best,bestScore=nil,math.huge; local now=os.clock()
    for _,e in ipairs(s.npcs or {}) do
        local isBoss=e.isBoss==true or e.classification=="BOSS"; local eligible=(kind=="BOSS" and isBoss) or (kind=="MOB" and not isBoss); local okAllowed=eligible and targetAllowed(e,kind)
        if okAllowed and matchesTarget(e,cfg) then
            local d=distance(p.position,e.position)
            if d and d<=maxDistance then
                local score=d; if e.maxHealth and e.maxHealth>0 then score=score-(1-(e.health/e.maxHealth))*8 end
                if kind=="BOSS" then local m=Brain.bossMemory[e.id]; if m and m.lastDownAt and now-m.lastDownAt<45 then score=score+250 end; if m and m.lastUnavailableAt and now-m.lastUnavailableAt<20 then score=score+90 end end
                if Brain.previousTargetId and e.id==Brain.previousTargetId then score=score-6 end
                if score<bestScore then best,bestScore=e,score end
            end
        end
    end
    if best then best=Util.deepCopy(best); best.distance=distance(p.position,best.position) end
    return best
end
local BossAvailabilityCache={alive=false,checkedAt=-math.huge}
local function hasAliveBoss()
    local now=os.clock()
    if now-(BossAvailabilityCache.checkedAt or -math.huge)<.60 then return BossAvailabilityCache.alive end
    local alive=false
    for _,e in ipairs((RAVYN.Features.snapshot or {}).npcs or {}) do
        local isBoss=e.isBoss==true or e.classification=="BOSS"
        if isBoss and targetAllowed(e,"BOSS") then alive=true; break end
    end
    BossAvailabilityCache.alive=alive; BossAvailabilityCache.checkedAt=now
    return alive
end
Hooks.chooseMode=function()
    local i=RAVYN.Config.Intelligence
    if i.AutoPlay then if hasAliveBoss() then return "BOSS",true,"AUTO PLAY · BOSS" end; return "MOB",true,"AUTO PLAY · FARM" end
    if RAVYN.Config.Farm.Boss.Enabled then return "BOSS",true,"BOSS FARM" end
    if RAVYN.Config.Farm.NormalMobs.Enabled then return "MOB",true,"MOB FARM" end
    if i.KillAura.Enabled then return "MOB",i.KillAura.Follow,"KILL AURA" end
    if RAVYN.Config.Combat.AutoAttack or RAVYN.Config.Combat.AutoAbilities then return "MOB",false,"COMBAT" end
    return nil,false,"IDLE"
end
local function selectAuraTarget()
    local s=RAVYN.Features.snapshot or {}; local p=s.player or {}; if not p.position then return nil end
    local maxD=AURA_MAP[RAVYN.Config.Intelligence.KillAura.Range] or 45; local best,bestD=nil,math.huge
    for _,e in ipairs(s.npcs or {}) do local isBoss=e.isBoss==true or e.classification=="BOSS"; if not isBoss and targetAllowed(e,"MOB") then local d=distance(p.position,e.position); if d and d<=maxD and d<bestD then best,bestD=e,d end end end
    if best then best=Util.deepCopy(best); best.distance=bestD end
    return best
end

function RAVYN:ClientSkillSmart(target,now)
    local keys=currentSkillKeys(); if #keys==0 then return result(false,"NO_VISIBLE_SKILL_KEYS") end
    local profile=Hooks.activeProfile(); local targetPct=(target and target.health and target.maxHealth and target.maxHealth>0) and (target.health/target.maxHealth*100) or 100
    local cm=RAVYN.Config and RAVYN.Config.CombatMobility
    local desiredM1=(cm and cm.Enabled and cm.AggressiveSkills) and 1 or ((RAVYN.Config.SmartCombat.Profile=="Aggressive") and 1 or ((RAVYN.Config.SmartCombat.Profile=="Safe") and 3 or 2))
    if not RAVYN.Config.Combat.AutoAttack or targetPct<=24 then desiredM1=0 end
    if Brain.combo.m1<desiredM1 then return result(false,"COMBO_WAIT_M1") end
    local best=nil
    for _,k in ipairs(keys) do local last=Brain.combo.lastSkillAt[k.key] or -math.huge; local cm=RAVYN.Config and RAVYN.Config.CombatMobility; local reuse=(cm and cm.Enabled and cm.AggressiveSkills) and math.max(.40,tonumber(cm.SkillInterval) or .55) or math.max(profile.skillDelay*2.2,2.2); if now-last>=reuse and k.key~=Brain.combo.lastSkillKey then best=k; break end end
    best=best or keys[(Brain.combo.stage-1)%#keys+1]
    -- v1.2.2: request through the CombatActionBus (hotbar key = identifier only)
    local B=RAVYN.CombatActionBus; if not B then return result(false,"COMBAT_BUS_UNAVAILABLE",best) end
    local r=B:RequestSkill(best,target,{source="SmartSkillsV37"}); LiveAction.lastInputSource=(r.value and r.value.backend) or r.code
    if r.ok then Brain.combo.lastSkillKey=best.key; Brain.combo.lastSkillAt[best.key]=now; Brain.combo.stage=(Brain.combo.stage%#keys)+1; Brain.combo.m1=0; Brain.combo.lastAction="SKILL "..best.key; self.Logger:log("INFO","SMART_SKILL_"..best.key,{target=target and target.name,index=best.index}); return result(true,"SMART_SKILL_SENT",best) end
    return result(false,r.code,best)
end

function RAVYN:SetAutoPlay(v)
    if type(v)~="boolean" then return result(false,"INVALID_CONFIG") end
    local r=self:SetConfig("Intelligence.AutoPlay",v); if not r.ok then return r end
    if v then self:SetFeature("ATTACK",true); self:SetFeature("ABILITIES",true); if self.FSM.state=="STOPPED" then self:Start() end end
    return result(true,v and "AUTO_PLAY_LIVE" or "AUTO_PLAY_OFF")
end
function RAVYN:SetKillAura(v)
    if type(v)~="boolean" then return result(false,"INVALID_CONFIG") end
    local r=self:SetConfig("Intelligence.KillAura.Enabled",v); if r.ok and v and self.FSM.state=="STOPPED" then self:Start() end
    return r.ok and result(true,v and "KILL_AURA_LIVE" or "KILL_AURA_OFF") or r
end
function RAVYN:SetSearchRadiusPreset(name) if not RADIUS_MAP[name] then return result(false,"UNKNOWN_RADIUS") end; return self:SetConfig("Intelligence.SearchRadius",name) end
function RAVYN:ResetRiskMeasures() Brain.lastHealth=nil; Brain.lastHealthAt=nil; Brain.damagePerSecond=0; Brain.riskScore=0; Brain.forceEvade=false; return result(true,"RISK_RESET") end
function RAVYN:AddNeverAttack(name)
    if not name or name=="" then return result(false,"INVALID_NAME") end
    local list=Util.deepCopy(self.Config.Intelligence.TargetRules.NeverAttack or {}); if not listContainsInsensitive(list,name) then table.insert(list,name) end
    return self:SetConfig("Intelligence.TargetRules.NeverAttack",list)
end
function RAVYN:ClearNeverAttack() return self:SetConfig("Intelligence.TargetRules.NeverAttack",{}) end

function RAVYN:SaveCurrentPlace()
    local root=liveRoot(); if not root then return result(false,"ROOT_UNAVAILABLE") end
    local list=Util.deepCopy(self.Config.Intelligence.SavedPlaces or {}); local nearest=self:GetObservedNPCs("ALL",1,"")[1]; local baseName=nearest and ("Near "..tostring(nearest.name)) or ("Saved "..tostring(#list+1)); local n=baseName; local suffix=2; local used={}; for _,p in ipairs(list) do used[p.name]=true end; while used[n] do n=baseName.." "..suffix; suffix+=1 end
    table.insert(list,{name=n,x=root.Position.X,y=root.Position.Y,z=root.Position.Z}); while #list>10 do table.remove(list,1) end
    local r=self:SetConfig("Intelligence.SavedPlaces",list); return r.ok and result(true,"PLACE_SAVED",{name=n}) or r
end
function RAVYN:TeleportToSavedPlace(index)
    local place=self.Config.Intelligence.SavedPlaces[index]; if type(place)~="table" then return result(false,"PLACE_NOT_FOUND") end
    local root=liveRoot(); if not root then return result(false,"ROOT_UNAVAILABLE") end
    cancelTween(); local pos=Vector3.new(place.x,place.y,place.z); local ok,err=safeSet(root,"CFrame",CFrame.new(pos)); return result(ok,ok and "PLACE_TELEPORTED" or "PLACE_TELEPORT_FAILED",ok and place or tostring(err))
end
function RAVYN:ClearSavedPlaces() return self:SetConfig("Intelligence.SavedPlaces",{}) end

local function ensureESPContainer()
    if Brain.esp.container and Brain.esp.container.Parent then return Brain.esp.container end
    local players=liveService("Players"); local player=players and players.LocalPlayer; local pg=player and player:FindFirstChildOfClass("PlayerGui"); if not pg then return nil end
    local folder=Instance.new("Folder"); folder.Name="RAVYN_ESP_V37"; folder.Parent=pg; Brain.esp.container=folder; return folder
end
local function destroyESPItem(id) local item=Brain.esp.items[id]; if item and item.gui then pcall(function() item.gui:Destroy() end) end; Brain.esp.items[id]=nil end
local function updateESP(now)
    if now-(Brain.esp.lastRefresh or 0)<.35 then return end; Brain.esp.lastRefresh=now
    local cfg=RAVYN.Config.Intelligence.ESP
    if not cfg.NPC and not cfg.Boss then for id in pairs(Brain.esp.items) do destroyESPItem(id) end; return end
    local container=ensureESPContainer(); if not container then return end
    local seen={}; local maxD=RADIUS_MAP[cfg.Range] or 250
    for _,e in ipairs((RAVYN.Features.snapshot or {}).npcs or {}) do
        local isBoss=e.isBoss==true or e.classification=="BOSS"; local allowed=(isBoss and cfg.Boss) or ((not isBoss) and cfg.NPC)
        if allowed and e.alive~=false and (e.distance or math.huge)<=maxD then
            local raw=RAVYN.ReadAdapter.lastEntities and RAVYN.ReadAdapter.lastEntities[e.id]; local root=raw and RAVYN.ReadAdapter:_entityRoot(raw) or nil
            if root then
                seen[e.id]=true; local item=Brain.esp.items[e.id]
                if not item then
                    local gui=Instance.new("BillboardGui"); gui.Name="RAVYN_ESP"; gui.Size=UDim2.fromOffset(190,42); gui.StudsOffset=Vector3.new(0,3.8,0); gui.AlwaysOnTop=true; gui.Adornee=root; gui.Parent=container
                    local label=Instance.new("TextLabel"); label.Size=UDim2.fromScale(1,1); label.BackgroundTransparency=1; label.TextStrokeTransparency=.38; label.TextSize=12; label.Font=Enum.Font.GothamSemibold; label.TextWrapped=true; label.Parent=gui
                    item={gui=gui,label=label}; Brain.esp.items[e.id]=item
                else item.gui.Adornee=root end
                local pct=(e.health and e.maxHealth and e.maxHealth>0) and math.floor(e.health/e.maxHealth*100+.5) or nil; local selected=LiveAction.targetId==e.id; local prefix=isBoss and "◆ BOSS" or "• MOB"; local risk=localRiskRating(e)
                item.label.Text=prefix.."  "..tostring(e.name)..(selected and "  ◉" or "").."\n"..(pct and (tostring(pct).."%  ·  ") or "")..tostring(math.floor((e.distance or 0)+.5)).." studs  ·  "..risk
                item.label.TextColor3=isBoss and Color3.fromRGB(231,191,72) or (selected and Color3.fromRGB(92,151,255) or Color3.fromRGB(245,245,248))
            end
        end
    end
    for id in pairs(Brain.esp.items) do if not seen[id] then destroyESPItem(id) end end
end
function RAVYN:SetESP(kind,v)
    if kind~="NPC" and kind~="Boss" then return result(false,"UNKNOWN_ESP_KIND") end
    local r=self:SetConfig("Intelligence.ESP."..kind,v==true)
    if r.ok and v==true and self.FSM.state=="STOPPED" then self:Start() end
    if r.ok and not self.Config.Intelligence.ESP.NPC and not self.Config.Intelligence.ESP.Boss then for id in pairs(Brain.esp.items) do destroyESPItem(id) end end
    return r
end
function RAVYN:SetAntiAFK(v) return self:SetConfig("Intelligence.AntiAFK",v==true) end
local function antiAfkPulse()
    if not RAVYN.Config.Intelligence.AntiAFK then return end
    local vu=liveService("VirtualUser"); if vu then
        local A=RAVYN.InputAudit; if A and A.note then A.note("MOUSE","anti-AFK M2","ANTI_AFK") end -- not combat; audited
        pcall(function() vu:CaptureController(); vu:ClickButton2(Vector2.new(0,0)) end)
    end
end
do local players=liveService("Players"); local p=players and players.LocalPlayer; if p and p.Idled then local c=p.Idled:Connect(antiAfkPulse); Brain.afkConnection=c; table.insert(RAVYN._connections,c) end end

function RAVYN:SaveRuntimeReport()
    local write=fileApi("writefile"); if not write then return result(false,"WRITEFILE_UNAVAILABLE") end
    local lines={"RAVYN "..tostring(self.Version),"Build: "..tostring(self.Build),"BrainState: "..tostring(Brain.state),"RiskScore: "..string.format("%.1f",Brain.riskScore or 0),"DamagePerSecond: "..string.format("%.1f",Brain.damagePerSecond or 0),"Target: "..tostring(LiveAction.target and LiveAction.target.name or "none"),"",self.ProbeReport or ""}
    local mk=fileApi("makefolder"); if mk then pcall(mk,"RAVYN") end
    local ok,err=pcall(write,"RAVYN/runtime_report_v3_7.txt",table.concat(lines,"\n")); return result(ok,ok and "REPORT_FILE_SAVED" or "REPORT_FILE_FAILED",ok and nil or tostring(err))
end
function RAVYN:ClearRuntimeLogs() self.Logger:clear(); return result(true,"LOGS_CLEARED") end
function RAVYN:CaptureParryEvidence(label) return self:CaptureProbe("Combat",label) end
function RAVYN:CompareParryEvidence()
    local c=self.Probes and self.Probes.captures and self.Probes.captures.Combat or {}
    local pairs={{"ParryIdle","ParryWindup"},{"ParryWindup","ParrySuccess"},{"ParryWindup","ParryHit"}}
    local out={}
    for _,pair in ipairs(pairs) do
        local r=Probe.diff(c[pair[1]],c[pair[2]],self.Probes.maxDiff)
        if not r.ok then return r end
        table.insert(out,r.value)
    end
    self:_showReport("PARRY EVIDENCE",{diff=out,captures={Idle=c.ParryIdle,Windup=c.ParryWindup,Success=c.ParrySuccess,Hit=c.ParryHit}})
    self.CombatDiffReport=self.ProbeReport
    return result(true,"PARRY_EVIDENCE_READY",out)
end

function RAVYN:_tick()
    local ap=self.AutoPlay38
    if ap and ap.stopRequested then
        ap.stopRequested=false
        if self.FSM.state=="RUNNING" or self.FSM.state=="PAUSED" then self:Stop() end
        return
    end
    if self.FSM.state~="RUNNING" then updateESP(os.clock()); return end
    local ok,res=pcall(function()
        local now=os.clock()
        if now-(LiveAction.lastScan or 0)>=.30 then LiveAction.lastScan=now; local rr=RAVYN:RefreshReadBindings(); if not rr.ok then return rr end end
        updateDamageRisk(now); updateBossMemory(now); updateESP(now)
        local humanoid=liveHumanoid(); if RAVYN.Config.Movement.SpeedEnabled and humanoid then pcall(function() humanoid.WalkSpeed=RAVYN.Config.Movement.Speed end) end
        local mode,allowMovement,modeLabel=Hooks.chooseMode(); local target=nil
        if RAVYN.Config.Intelligence.KillAura.Enabled and not RAVYN.Config.Intelligence.AutoPlay and not RAVYN.Config.Farm.Boss.Enabled and not RAVYN.Config.Farm.NormalMobs.Enabled then target=selectAuraTarget() elseif mode then target=selectBrainTarget(mode,allowMovement) end
        local previousId=LiveAction.targetId
        if target and previousId~=target.id then Brain.previousTargetId=previousId; Brain.combo.m1=0; Brain.combo.stage=1; setBrainState("ACQUIRE") elseif not target and previousId then Brain.previousTargetId=previousId; Brain.lastTargetLostAt=now; setBrainState("RETARGETING") end
        LiveAction.target=target; LiveAction.targetId=target and target.id or nil; RAVYN.Features.currentTarget=target
        if not target then cancelTween(); LiveAction.positionMode="IDLE"; LiveAction.evading=Brain.forceEvade; setBrainState(mode and "SCANNING" or "IDLE"); LiveAction.lastMessage=(mode and (modeLabel.." · SCANNING") or "IDLE"); return result(true,"BRAIN_IDLE") end
        local d=target.distance or math.huge; local profile=Hooks.activeProfile(); local evading=Brain.forceEvade or LiveAction.evading
        if allowMovement or evading then
            if evading then setBrainState("EVADING") elseif d>profile.attackDistance*1.35 then setBrainState("APPROACHING") else setBrainState("POSITIONING") end
            if now-Brain.lastReposition>=math.max(.35,RAVYN.Config.Intelligence.CombatBrain.RepositionInterval) or evading then Brain.lastReposition=now; local mr=moveSmart(target,false); LiveAction.lastMessage=mr.code else faceTarget(liveRoot(),targetBasis(target)) end
        else faceTarget(liveRoot(),targetBasis(target)) end
        evading=Brain.forceEvade or LiveAction.evading; local attackRange=profile.attackDistance; local skillRange=math.max(attackRange+7,16)
        -- v3.8.4: when the CombatMobility executor owns dispatch, this legacy path sends nothing (single executor).
        local exec384=RAVYN.CombatMobility and RAVYN.CombatMobility.executorOwns
        if not evading and not exec384 and d<=attackRange and RAVYN.Config.Combat.AutoAttack and now-LiveAction.lastAttack>=profile.attackCooldown then setBrainState("COMBO"); local r=RAVYN:ClientAttack(); if r.ok then LiveAction.lastAttack=now; Brain.combo.m1=Brain.combo.m1+1; Brain.combo.lastAction="M1" end end
        if not evading and not exec384 and d<=skillRange and RAVYN.Config.Combat.AutoAbilities and RAVYN.Config.Intelligence.CombatBrain.SmartCombo and now-LiveAction.lastSkill>=profile.skillDelay then local r=RAVYN:ClientSkillSmart(target,now); if r.ok then LiveAction.lastSkill=now end
        elseif not evading and not exec384 and d<=skillRange and RAVYN.Config.Combat.AutoAbilities and not RAVYN.Config.Intelligence.CombatBrain.SmartCombo and now-LiveAction.lastSkill>=profile.skillDelay then local r=RAVYN:ClientSkill(); if r.ok then LiveAction.lastSkill=now end end
        if evading then setBrainState("EVADING"); LiveAction.lastMessage=string.format("EVADE · HP %.0f%% · RISK %.0f",healthPercent(),Brain.riskScore)
        else if Brain.state~="COMBO" then setBrainState("ATTACKING") end; local rating=localRiskRating(target); LiveAction.lastMessage=Brain.state.." · "..tostring(target.name).." · "..rating end
        return result(true,"INTELLIGENCE_TICK")
    end)
    if not ok then self.Telemetry.actionsFailed=self.Telemetry.actionsFailed+1; self.Features.lastError=tostring(res); self.Logger:log("ERROR",tostring(res)) end
end

local stopBeforeV37=RAVYN.Stop
function RAVYN:Stop() Brain.state="IDLE"; Brain.forceEvade=false; Brain.combo.m1=0; Brain.combo.stage=1; return stopBeforeV37(self) end
local destroyBeforeV37=RAVYN.Destroy
function RAVYN:Destroy() for id in pairs(Brain.esp.items) do destroyESPItem(id) end; if Brain.esp.container then pcall(function() Brain.esp.container:Destroy() end) end; return destroyBeforeV37(self) end
CTX["validateV37Base"]=validateV37Base
CTX["Brain"]=Brain
CTX["RADIUS_MAP"]=RADIUS_MAP
CTX["AURA_MAP"]=AURA_MAP
CTX["ATTACK_RANGE_MAP"]=ATTACK_RANGE_MAP
CTX["SKILL_TEMPO_MAP"]=SKILL_TEMPO_MAP
CTX["DISTANCE_MAP"]=DISTANCE_MAP
CTX["TRAVEL_SPEED_MAP"]=TRAVEL_SPEED_MAP
CTX["setBrainState"]=setBrainState
CTX["listContainsInsensitive"]=listContainsInsensitive
CTX["baseActiveProfileV37"]=baseActiveProfileV37
CTX["playerSnapshot"]=playerSnapshot
CTX["updateDamageRisk"]=updateDamageRisk
CTX["baseSmartDestinationV37"]=baseSmartDestinationV37
CTX["localRiskRating"]=localRiskRating
CTX["targetAllowed"]=targetAllowed
CTX["updateBossMemory"]=updateBossMemory
CTX["smartSearchRadius"]=smartSearchRadius
CTX["selectBrainTarget"]=selectBrainTarget
CTX["BossAvailabilityCache"]=BossAvailabilityCache
CTX["hasAliveBoss"]=hasAliveBoss
CTX["selectAuraTarget"]=selectAuraTarget
CTX["ensureESPContainer"]=ensureESPContainer
CTX["destroyESPItem"]=destroyESPItem
CTX["updateESP"]=updateESP
CTX["antiAfkPulse"]=antiAfkPulse
CTX["stopBeforeV37"]=stopBeforeV37
CTX["destroyBeforeV37"]=destroyBeforeV37
return true]==========]); if not ok then return end end
do local ok=runChunk("AutoPlayV38.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Util=CTX["Util"]
local Logger=CTX["Logger"]
local Config=CTX["Config"]
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local v3=CTX["v3"]
local Brain=CTX["Brain"]
local BossAvailabilityCache=CTX["BossAvailabilityCache"]
local hasAliveBoss=CTX["hasAliveBoss"]
-- v3.8 master orchestration layer. Uses only already-live client actions from v3.7.
-- Quest, loot/chest and perfect-parry actions remain unresolved until evidence proves exact bindings.
RAVYN.Version="3.8.0.1-autoplay"
RAVYN.Build="2026-09-26-v3.8.0.1-autoplay-fix"

Config.Default.AutoPlayV38={
    Mode="Smart",                 -- Smart | Bosses | Mobs
    BossRotation=true,
    PreFarm=true,
    AutoAttack=true,
    AutoSkills=true,
    AutoESP=false,
    StopAfterBosses=0,             -- 0 = never
}
RAVYN.Config.AutoPlayV38=Util.deepMerge(Config.Default.AutoPlayV38,RAVYN.Config.AutoPlayV38 or {})

local validateV38Base=Config.validate
function Config.validate(c)
    local ok,errors=validateV38Base(c)
    local a=c.AutoPlayV38
    if type(a)~="table" then
        table.insert(errors,"AutoPlayV38")
    else
        local modes={Smart=true,Bosses=true,Mobs=true}
        if not modes[a.Mode] then table.insert(errors,"AutoPlayV38.Mode") end
        if type(a.BossRotation)~="boolean" then table.insert(errors,"AutoPlayV38.BossRotation") end
        if type(a.PreFarm)~="boolean" then table.insert(errors,"AutoPlayV38.PreFarm") end
        if type(a.AutoAttack)~="boolean" then table.insert(errors,"AutoPlayV38.AutoAttack") end
        if type(a.AutoSkills)~="boolean" then table.insert(errors,"AutoPlayV38.AutoSkills") end
        if type(a.AutoESP)~="boolean" then table.insert(errors,"AutoPlayV38.AutoESP") end
        if type(a.StopAfterBosses)~="number" or a.StopAfterBosses<0 or a.StopAfterBosses%1~=0 then table.insert(errors,"AutoPlayV38.StopAfterBosses") end
    end
    return #errors==0,errors
end

local AutoPlay38={
    activity="IDLE",reason="READY",startedAt=nil,bossesDefeated=0,retargets=0,
    lastTargetId=nil,lastNonNilTargetId=nil,lastTargetName=nil,lastDecisionAt=0,lastBossDown={},stoppedByLimit=false,
    stopRequested=false,bossCache=BossAvailabilityCache,
}
RAVYN.AutoPlay38=AutoPlay38

function AutoPlay38:resetSession()
    self.activity="SCANNING"; self.reason="SESSION STARTED"; self.startedAt=os.clock()
    self.bossesDefeated=0; self.retargets=0; self.lastTargetId=nil; self.lastNonNilTargetId=nil; self.lastTargetName=nil
    self.lastDecisionAt=os.clock(); self.lastBossDown={}; self.stoppedByLimit=false; self.stopRequested=false
end

function AutoPlay38:observe()
    for id,m in pairs(Brain.bossMemory or {}) do
        local down=tonumber(m.lastDownAt)
        if down and down>(self.lastBossDown[id] or -math.huge) then
            self.lastBossDown[id]=down
            self.bossesDefeated=self.bossesDefeated+1
            RAVYN.Logger:log("INFO","AUTOPLAY_BOSS_DOWN",{boss=m.name,id=id,total=self.bossesDefeated})
        end
    end
    local tid=LiveAction.targetId
    if tid then
        if self.lastNonNilTargetId and tid~=self.lastNonNilTargetId then self.retargets=self.retargets+1 end
        self.lastNonNilTargetId=tid
        self.lastTargetId=tid
        self.lastTargetName=LiveAction.target and LiveAction.target.name or self.lastTargetName
    else
        self.lastTargetId=nil
    end
end

function AutoPlay38:setDecision(activity,reason)
    self.activity=activity or "IDLE"; self.reason=reason or ""; self.lastDecisionAt=os.clock()
end

local chooseModeV37=Hooks.chooseMode
Hooks.chooseMode=function()
    if not RAVYN.Config.Intelligence.AutoPlay then
        return chooseModeV37()
    end

    AutoPlay38:observe()
    local cfg=RAVYN.Config.AutoPlayV38
    local limit=tonumber(cfg.StopAfterBosses) or 0
    if limit>0 and AutoPlay38.bossesDefeated>=limit then
        RAVYN:SetConfig("Intelligence.AutoPlay",false)
        RAVYN:SetFeature("NORMAL_MOB",false); RAVYN:SetFeature("BOSS",false)
        RAVYN:SetFeature("ATTACK",false); RAVYN:SetFeature("ABILITIES",false)
        AutoPlay38.stoppedByLimit=true
        AutoPlay38.stopRequested=true
        AutoPlay38:setDecision("COMPLETE","STOP LIMIT REACHED")
        return nil,false,"AUTO PLAY · COMPLETE"
    end

    local bossAvailable=hasAliveBoss()
    if Brain.forceEvade or LiveAction.evading then
        AutoPlay38:setDecision("EVADING","SMART SAFETY")
    end

    if cfg.Mode=="Bosses" then
        if bossAvailable then
            AutoPlay38:setDecision("BOSS ROTATION","BOSS AVAILABLE")
            return "BOSS",true,"AUTO PLAY · BOSS"
        end
        AutoPlay38:setDecision("WAITING","NO STREAMED BOSS")
        return nil,false,"AUTO PLAY · WAITING BOSS"
    end

    if cfg.Mode=="Mobs" then
        AutoPlay38:setDecision("MOB FARM","MOBS MODE")
        return "MOB",true,"AUTO PLAY · MOBS"
    end

    -- Smart: bosses first; farm normal mobs while no eligible boss is currently available.
    if cfg.BossRotation and bossAvailable then
        AutoPlay38:setDecision("BOSS ROTATION","ELIGIBLE BOSS FOUND")
        return "BOSS",true,"AUTO PLAY · BOSS"
    end
    if cfg.PreFarm then
        AutoPlay38:setDecision("PRE-FARM","NO ELIGIBLE BOSS")
        return "MOB",true,"AUTO PLAY · PRE-FARM"
    end
    AutoPlay38:setDecision("SCANNING","WAITING FOR BOSS")
    return nil,false,"AUTO PLAY · SCANNING"
end

local setAutoPlayV37=RAVYN.SetAutoPlay
function RAVYN:SetAutoPlay(v)
    if type(v)~="boolean" then return result(false,"INVALID_CONFIG") end
    if v and not self.Config.Intelligence.AutoPlay then AutoPlay38:resetSession() end
    local r=setAutoPlayV37(self,v)
    if not r.ok then return r end
    if v then
        self:SetFeature("ATTACK",self.Config.AutoPlayV38.AutoAttack)
        self:SetFeature("ABILITIES",self.Config.AutoPlayV38.AutoSkills)
        self:SetConfig("SmartCombat.Enabled",true)
        if self.Config.AutoPlayV38.AutoESP then self:SetESP("Boss",true); self:SetESP("NPC",true) end
        self:SetAntiAFK(true)
        AutoPlay38:setDecision("SCANNING","AUTO PLAY ENABLED")
        return result(true,"AUTO_PLAY_V38_LIVE")
    end
    AutoPlay38:setDecision("IDLE","AUTO PLAY OFF")
    return result(true,"AUTO_PLAY_V38_OFF")
end

function RAVYN:SetAutoPlayMode(mode)
    local allowed={Smart=true,Bosses=true,Mobs=true}
    if not allowed[mode] then return result(false,"UNKNOWN_AUTOPLAY_MODE") end
    return self:SetConfig("AutoPlayV38.Mode",mode)
end
function RAVYN:SetAutoPlayBossRotation(v)
    if type(v)~="boolean" then return result(false,"INVALID_CONFIG") end
    return self:SetConfig("AutoPlayV38.BossRotation",v)
end
function RAVYN:SetAutoPlayPreFarm(v)
    if type(v)~="boolean" then return result(false,"INVALID_CONFIG") end
    return self:SetConfig("AutoPlayV38.PreFarm",v)
end
function RAVYN:SetAutoPlayAttack(v)
    if type(v)~="boolean" then return result(false,"INVALID_CONFIG") end
    local r=self:SetConfig("AutoPlayV38.AutoAttack",v); if not r.ok then return r end
    if self.Config.Intelligence.AutoPlay then return self:SetFeature("ATTACK",v) end
    return r
end
function RAVYN:SetAutoPlaySkills(v)
    if type(v)~="boolean" then return result(false,"INVALID_CONFIG") end
    local r=self:SetConfig("AutoPlayV38.AutoSkills",v); if not r.ok then return r end
    if self.Config.Intelligence.AutoPlay then return self:SetFeature("ABILITIES",v) end
    return r
end
function RAVYN:SetAutoPlayESP(v)
    if type(v)~="boolean" then return result(false,"INVALID_CONFIG") end
    local r=self:SetConfig("AutoPlayV38.AutoESP",v); if not r.ok then return r end
    if self.Config.Intelligence.AutoPlay then self:SetESP("Boss",v); self:SetESP("NPC",v) end
    return r
end
function RAVYN:SetAutoPlayStopAfterBosses(n)
    n=tonumber(n)
    if not n or n<0 or n%1~=0 then return result(false,"INVALID_LIMIT") end
    return self:SetConfig("AutoPlayV38.StopAfterBosses",n)
end
function RAVYN:GetAutoPlayStatus()
    local target=LiveAction.target
    return {
        enabled=self.Config.Intelligence.AutoPlay==true,
        activity=AutoPlay38.activity,
        reason=AutoPlay38.reason,
        brain=Brain.state,
        target=target and target.name or nil,
        targetId=target and target.id or nil,
        risk=Brain.riskScore or 0,
        damagePerSecond=Brain.damagePerSecond or 0,
        bossesDefeated=AutoPlay38.bossesDefeated,
        retargets=AutoPlay38.retargets,
        stopAfterBosses=self.Config.AutoPlayV38.StopAfterBosses,
        mode=self.Config.AutoPlayV38.Mode,
        unresolved={quest="UNRESOLVED_GAME_BINDING",loot="UNRESOLVED_GAME_BINDING",perfectParry="EVIDENCE_REQUIRED"},
    }
end

-- Auto Play intentionally does not fire unknown quest/loot/parry actions.
-- These remain visible as capability blockers instead of fake working toggles.
CTX["validateV38Base"]=validateV38Base
CTX["AutoPlay38"]=AutoPlay38
CTX["chooseModeV37"]=chooseModeV37
CTX["setAutoPlayV37"]=setAutoPlayV37
return true]==========]); if not ok then return end end
do local ok=runChunk("UI.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Logger=CTX["Logger"]
local Config=CTX["Config"]
local result=CTX["result"]
local get=CTX["get"]
local distance=CTX["distance"]
local RAVYN=CTX["RAVYN"]
local serialize=CTX["serialize"]
local LiveAction=CTX["LiveAction"]
local v3=CTX["v3"]
local Brain=CTX["Brain"]
-- RAVYN Obsidian UI v3.8: Auto Play master orchestration + combat intelligence.
local function mountUI()
    if not RAVYN.Config.UI.Enabled then return end
    local ok,err=pcall(function()
        local Players=game:GetService("Players")
        local UIS=game:GetService("UserInputService")
        local TweenService=game:GetService("TweenService")
        local player=Players.LocalPlayer
        if not player then return end
        local parent=player:FindFirstChildOfClass("PlayerGui")
        if not parent then return end

        local C={
            bg=Color3.fromRGB(10,10,12),
            panel=Color3.fromRGB(18,18,21),
            card=Color3.fromRGB(25,25,29),
            raised=Color3.fromRGB(31,31,36),
            text=Color3.fromRGB(246,246,248),
            muted=Color3.fromRGB(151,151,160),
            faint=Color3.fromRGB(92,92,101),
            gold=Color3.fromRGB(231,191,72),
            goldDim=Color3.fromRGB(73,61,27),
            green=Color3.fromRGB(69,201,124),
            red=Color3.fromRGB(239,94,94),
            orange=Color3.fromRGB(255,165,70),
            blue=Color3.fromRGB(92,151,255),
            line=Color3.fromRGB(48,48,55),
        }
        local function node(class,parentNode,props)
            local x=Instance.new(class)
            for k,v in pairs(props or {}) do x[k]=v end
            x.Parent=parentNode
            return x
        end
        local function round(x,r) node("UICorner",x,{CornerRadius=UDim.new(0,r or 12)}) end
        local function stroke(x,color,t,trans)
            node("UIStroke",x,{Color=color or C.line,Thickness=t or 1,Transparency=trans==nil and .22 or trans})
        end
        local function pad(x,l,r,t,b)
            node("UIPadding",x,{
                PaddingLeft=UDim.new(0,l or 0),PaddingRight=UDim.new(0,r or l or 0),
                PaddingTop=UDim.new(0,t or 0),PaddingBottom=UDim.new(0,b or t or 0)
            })
        end
        local function tw(obj,duration,props,style,direction)
            local t=TweenService:Create(obj,TweenInfo.new(duration or .22,style or Enum.EasingStyle.Quint,direction or Enum.EasingDirection.Out),props)
            t:Play(); return t
        end

        local cam=workspace.CurrentCamera
        local viewport=(cam and cam.ViewportSize) or Vector2.new(1600,900)
        local winW=math.floor(math.clamp(viewport.X*.58,760,1020))
        local winH=math.floor(math.clamp(viewport.Y*.70,520,660))

        local gui=node("ScreenGui",parent,{Name="RAVYN_V3_8_OBSIDIAN",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=true})
        RAVYN._gui=gui

        local shadow=node("Frame",gui,{Size=UDim2.fromOffset(winW+14,winH+14),Position=UDim2.new(.5,-winW/2-7,.5,-winH/2-1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.78,BorderSizePixel=0})
        round(shadow,25)

        local window=node("CanvasGroup",gui,{Size=UDim2.fromOffset(winW,winH),Position=UDim2.new(.5,-winW/2,.5,-winH/2-8),BackgroundColor3=C.bg,BackgroundTransparency=.01,BorderSizePixel=0,GroupTransparency=1,ClipsDescendants=true,Active=true})
        round(window,21); stroke(window,C.line,1,.10)
        local windowScale=node("UIScale",window,{Scale=.94})
        tw(windowScale,.44,{Scale=1},Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
        tw(window,.34,{GroupTransparency=0},Enum.EasingStyle.Quint,Enum.EasingDirection.Out)

        local top=node("Frame",window,{Size=UDim2.new(1,0,0,58),BackgroundColor3=C.panel,BorderSizePixel=0,Active=true})
        node("Frame",top,{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=C.line,BorderSizePixel=0})
        node("TextLabel",top,{Size=UDim2.fromOffset(100,58),Position=UDim2.fromOffset(18,0),BackgroundTransparency=1,Text="RAVYN",TextColor3=C.text,TextSize=18,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})
        local liveChip=node("TextLabel",top,{Size=UDim2.fromOffset(128,24),Position=UDim2.fromOffset(100,17),BackgroundColor3=C.goldDim,Text="SLAYERS 2  ·  AUTO PLAY",TextColor3=C.gold,TextSize=9,Font=Enum.Font.GothamBold,BorderSizePixel=0})
        round(liveChip,12)

        local hideBtn=node("TextButton",top,{Size=UDim2.fromOffset(34,34),Position=UDim2.new(1,-78,.5,-17),BackgroundColor3=C.card,Text="—",TextColor3=C.text,TextSize=17,Font=Enum.Font.GothamBold,BorderSizePixel=0,AutoButtonColor=false})
        round(hideBtn,11)
        local closeBtn=node("TextButton",top,{Size=UDim2.fromOffset(34,34),Position=UDim2.new(1,-40,.5,-17),BackgroundColor3=C.card,Text="×",TextColor3=C.text,TextSize=17,Font=Enum.Font.GothamBold,BorderSizePixel=0,AutoButtonColor=false})
        round(closeBtn,11)

        local reopen=node("CanvasGroup",gui,{Size=UDim2.fromOffset(122,42),Position=UDim2.new(0,22,.5,-21),BackgroundColor3=C.panel,BackgroundTransparency=.03,GroupTransparency=1,Visible=false,BorderSizePixel=0})
        round(reopen,21); stroke(reopen,C.line,1,.12)
        local reopenBtn=node("TextButton",reopen,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="RAVYN   ◇",TextColor3=C.gold,TextSize=12,Font=Enum.Font.GothamBold,BorderSizePixel=0})

        local hidden=false; local animBusy=false
        local function setHidden(v)
            if animBusy or hidden==v then return end
            animBusy=true; hidden=v
            if v then
                tw(windowScale,.23,{Scale=.955},Enum.EasingStyle.Quint,Enum.EasingDirection.In)
                tw(window,.20,{GroupTransparency=1},Enum.EasingStyle.Quint,Enum.EasingDirection.In)
                task.delay(.21,function()
                    if hidden and RAVYN._gui==gui then
                        window.Visible=false; shadow.Visible=false; reopen.Visible=true
                        reopen.GroupTransparency=1; reopen.Position=UDim2.new(0,8,.5,-21)
                        tw(reopen,.32,{GroupTransparency=0,Position=UDim2.new(0,22,.5,-21)},Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
                    end; animBusy=false
                end)
            else
                tw(reopen,.18,{GroupTransparency=1,Position=UDim2.new(0,8,.5,-21)},Enum.EasingStyle.Quint,Enum.EasingDirection.In)
                task.delay(.16,function()
                    if not hidden and RAVYN._gui==gui then
                        reopen.Visible=false; window.Visible=true; shadow.Visible=true
                        window.GroupTransparency=1; windowScale.Scale=.94
                        tw(window,.28,{GroupTransparency=0},Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
                        tw(windowScale,.40,{Scale=1},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
                    end; animBusy=false
                end)
            end
        end

        table.insert(RAVYN._connections,hideBtn.Activated:Connect(function() setHidden(true) end))
        table.insert(RAVYN._connections,reopenBtn.Activated:Connect(function() setHidden(false) end))
        table.insert(RAVYN._connections,closeBtn.Activated:Connect(function() RAVYN:Destroy() end))
        table.insert(RAVYN._connections,UIS.InputBegan:Connect(function(input,gp)
            if not gp and input.KeyCode==Enum.KeyCode.RightControl then setHidden(not hidden) end
        end))

        local dragging=false; local dragStart=nil; local startPos=nil
        table.insert(RAVYN._connections,top.InputBegan:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                dragging=true; dragStart=input.Position; startPos=window.Position
            end
        end))
        table.insert(RAVYN._connections,UIS.InputEnded:Connect(function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
        end))
        table.insert(RAVYN._connections,UIS.InputChanged:Connect(function(input)
            if dragging and dragStart and startPos and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
                local d=input.Position-dragStart
                window.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
                shadow.Position=UDim2.new(window.Position.X.Scale,window.Position.X.Offset-7,window.Position.Y.Scale,window.Position.Y.Offset-7)
            end
        end))

        local sidebarW=168
        local sidebar=node("Frame",window,{Size=UDim2.new(0,sidebarW,1,-58),Position=UDim2.fromOffset(0,58),BackgroundColor3=C.panel,BorderSizePixel=0})
        local search=node("TextBox",sidebar,{Size=UDim2.new(1,-20,0,36),Position=UDim2.fromOffset(10,12),BackgroundColor3=C.card,Text="",PlaceholderText="Search…",PlaceholderColor3=C.faint,TextColor3=C.text,TextSize=11,Font=Enum.Font.Gotham,ClearTextOnFocus=false,BorderSizePixel=0})
        round(search,10)
        local nav=node("Frame",sidebar,{Size=UDim2.new(1,-16,1,-70),Position=UDim2.fromOffset(8,62),BackgroundTransparency=1})
        node("UIListLayout",nav,{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder})

        local content=node("Frame",window,{Size=UDim2.new(1,-sidebarW,1,-58),Position=UDim2.fromOffset(sidebarW,58),BackgroundColor3=C.bg,BorderSizePixel=0})
        local heading=node("TextLabel",content,{Size=UDim2.new(1,-40,0,30),Position=UDim2.fromOffset(22,16),BackgroundTransparency=1,Text="Home",TextColor3=C.text,TextSize=21,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})
        node("TextLabel",content,{Size=UDim2.new(1,-40,0,22),Position=UDim2.fromOffset(22,45),BackgroundTransparency=1,Text="Smart automation · only verified actions run",TextColor3=C.muted,TextSize=10,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left})
        local pagesHost=node("Frame",content,{Size=UDim2.new(1,-36,1,-105),Position=UDim2.fromOffset(18,76),BackgroundTransparency=1})

        local toast=node("CanvasGroup",content,{Size=UDim2.fromOffset(300,36),Position=UDim2.new(1,-318,1,-48),BackgroundColor3=C.raised,BackgroundTransparency=.04,GroupTransparency=1,BorderSizePixel=0,ZIndex=20})
        round(toast,18); stroke(toast,C.line,1,.25)
        local toastText=node("TextLabel",toast,{Size=UDim2.new(1,-24,1,0),Position=UDim2.fromOffset(12,0),BackgroundTransparency=1,Text="READY",TextColor3=C.text,TextSize=10,Font=Enum.Font.GothamSemibold,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=21})
        local toastToken=0
        local function notify(message,good)
            toastToken+=1; local token=toastToken
            toastText.Text=tostring(message or "OK")
            toastText.TextColor3=(good==false) and C.red or ((good==true) and C.green or C.text)
            toast.GroupTransparency=1; toast.Position=UDim2.new(1,-306,1,-48)
            tw(toast,.22,{GroupTransparency=0,Position=UDim2.new(1,-318,1,-48)},Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
            task.delay(2.4,function()
                if toastToken==token and RAVYN._gui==gui then tw(toast,.30,{GroupTransparency=1,Position=UDim2.new(1,-306,1,-48)},Enum.EasingStyle.Quint,Enum.EasingDirection.In) end
            end)
        end

        -- Base widget helpers
        local function lbl(parentNode,value,h,size,color,bold)
            return node("TextLabel",parentNode,{Size=UDim2.new(1,0,0,h or 24),BackgroundTransparency=1,Text=value or "",TextColor3=color or C.text,TextSize=size or 11,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true})
        end
        local function scroll(parentNode)
            local x=node("ScrollingFrame",parentNode,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.fromOffset(0,0),ScrollBarThickness=2,ScrollBarImageColor3=C.gold})
            node("UIListLayout",x,{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder})
            pad(x,0,3,0,10); return x
        end
        local function section(parentNode,titleText,subtitleText)
            local card=node("Frame",parentNode,{Size=UDim2.new(1,-3,0,56),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C.panel,BorderSizePixel=0})
            round(card,15); stroke(card,C.line,1,.28); pad(card,14,14,12,12)
            node("UIListLayout",card,{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder})
            lbl(card,titleText,20,12,C.text,true)
            if subtitleText and subtitleText~="" then lbl(card,subtitleText,25,10,C.muted,false) end
            return card
        end

        -- HP helpers
        local function fmt(v)
            if v==nil then return "—" end
            if type(v)=="number" then return tostring(math.floor(v*10+.5)/10) end
            return tostring(v)
        end
        local function hpBar(pct,w)
            w=w or 8; pct=math.max(0,math.min(100,pct or 0))
            local f=math.floor(pct/100*w+.5)
            return string.rep("█",f)..string.rep("░",w-f)
        end
        local function hpColor(pct)
            if pct<=25 then return C.red elseif pct<=50 then return C.orange else return C.green end
        end

        -- Button widget
        local function action(parentNode,title,fn,accent)
            local b=node("TextButton",parentNode,{Size=UDim2.new(1,0,0,38),BackgroundColor3=accent and C.goldDim or C.card,Text=title,TextColor3=accent and C.gold or C.text,TextSize=11,Font=Enum.Font.GothamSemibold,BorderSizePixel=0,AutoButtonColor=false})
            round(b,11)
            table.insert(RAVYN._connections,b.MouseEnter:Connect(function() tw(b,.15,{BackgroundColor3=accent and Color3.fromRGB(88,72,28) or C.raised}) end))
            table.insert(RAVYN._connections,b.MouseLeave:Connect(function() tw(b,.18,{BackgroundColor3=accent and C.goldDim or C.card}) end))
            table.insert(RAVYN._connections,b.Activated:Connect(function()
                tw(b,.08,{Size=UDim2.new(1,-4,0,36)},Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
                task.delay(.08,function() if b.Parent then tw(b,.16,{Size=UDim2.new(1,0,0,38)},Enum.EasingStyle.Back,Enum.EasingDirection.Out) end end)
                local ok2,r=pcall(fn)
                if not ok2 then RAVYN.Logger:log("ERROR",tostring(r)); notify(tostring(r),false)
                else notify(type(r)=="table" and (r.code or "OK") or "OK",not(type(r)=="table" and r.ok==false)) end
            end))
            return b
        end

        local refreshers={}

        -- Toggle with optional inline status chip
        local function toggle(parentNode,labelText,getter,setter,detail,statusFn)
            local row=node("Frame",parentNode,{Size=UDim2.new(1,0,0,50),BackgroundTransparency=1})
            local lw=lbl(row,labelText,19,11,C.text,true); lw.Position=UDim2.fromOffset(0,3); lw.Size=UDim2.new(1,-60,0,19)
            if detail then local d=lbl(row,detail,18,9,C.muted,false); d.Position=UDim2.fromOffset(0,25); d.Size=UDim2.new(1,-60,0,18) end
            if statusFn then
                local sBg=node("Frame",row,{Size=UDim2.fromOffset(56,16),Position=UDim2.new(1,-116,0,4),BackgroundColor3=C.card,BorderSizePixel=0})
                round(sBg,7)
                local sL=node("TextLabel",sBg,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="LIVE",TextColor3=C.green,TextSize=8,Font=Enum.Font.GothamBold})
                table.insert(refreshers,function() local s2,c=statusFn(); sL.Text=s2 or "?"; sL.TextColor3=c or C.muted end)
            end
            local b=node("TextButton",row,{Size=UDim2.fromOffset(44,26),Position=UDim2.new(1,-44,.5,-13),BackgroundColor3=C.raised,Text="",BorderSizePixel=0,AutoButtonColor=false})
            round(b,13)
            local knob=node("Frame",b,{Size=UDim2.fromOffset(20,20),Position=UDim2.fromOffset(3,3),BackgroundColor3=C.text,BorderSizePixel=0})
            round(knob,10)
            local function refresh(animate)
                local on=getter()
                if animate==false then b.BackgroundColor3=on and C.gold or C.raised; knob.Position=on and UDim2.fromOffset(21,3) or UDim2.fromOffset(3,3)
                else tw(b,.20,{BackgroundColor3=on and C.gold or C.raised},Enum.EasingStyle.Quint); tw(knob,.26,{Position=on and UDim2.fromOffset(21,3) or UDim2.fromOffset(3,3)},Enum.EasingStyle.Back) end
            end
            table.insert(RAVYN._connections,b.Activated:Connect(function()
                local wanted=not getter(); local ok2,r=pcall(setter,wanted)
                if not ok2 then notify(tostring(r),false) else notify(type(r)=="table" and (r.code or "OK") or "OK",not(type(r)=="table" and r.ok==false)) end
                refresh(true)
            end))
            refresh(false); return refresh
        end

        local function segmented(parentNode,items,getter,setter)
            local row=node("Frame",parentNode,{Size=UDim2.new(1,0,0,38),BackgroundColor3=C.card,BorderSizePixel=0})
            round(row,11); pad(row,3,3,3,3)
            node("UIListLayout",row,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder})
            local btns={}
            for _,item in ipairs(items) do
                local b=node("TextButton",row,{Size=UDim2.new(1/#items,-3,1,0),BackgroundColor3=C.card,BackgroundTransparency=1,Text=item,TextColor3=C.muted,TextSize=10,Font=Enum.Font.GothamSemibold,BorderSizePixel=0,AutoButtonColor=false})
                round(b,9); btns[item]=b
                table.insert(RAVYN._connections,b.Activated:Connect(function()
                    local ok2,r=pcall(setter,item)
                    if ok2 then notify(type(r)=="table" and (r.code or item) or item,not(type(r)=="table" and r.ok==false)) else notify(tostring(r),false) end
                    for k,btn in pairs(btns) do local ac=getter()==k; tw(btn,.18,{BackgroundTransparency=ac and 0 or 1,BackgroundColor3=ac and C.raised or C.card,TextColor3=ac and C.text or C.muted}) end
                end))
            end
            local function refresh() for k,btn in pairs(btns) do local ac=getter()==k; btn.BackgroundTransparency=ac and 0 or 1; btn.BackgroundColor3=ac and C.raised or C.card; btn.TextColor3=ac and C.text or C.muted end end
            refresh(); return refresh
        end

        local function dynamic(parentNode,fn,h,color,bold)
            local x=lbl(parentNode,"",h or 24,10,color or C.muted,bold)
            table.insert(refreshers,function() x.Text=fn() end); return x
        end

        -- Richer NPC row: badge | name | hp bar | distance
        local function npcRow(parentNode,onClick)
            local rowBg=node("Frame",parentNode,{Size=UDim2.new(1,0,0,40),BackgroundColor3=C.card,BorderSizePixel=0,Visible=false})
            round(rowBg,9)
            local badgeL=node("TextLabel",rowBg,{Size=UDim2.fromOffset(54,40),Position=UDim2.fromOffset(10,0),BackgroundTransparency=1,Text="•  MOB",TextColor3=C.faint,TextSize=8,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})
            local nameL=node("TextLabel",rowBg,{Size=UDim2.new(1,-194,1,0),Position=UDim2.fromOffset(66,0),BackgroundTransparency=1,Text="",TextColor3=C.text,TextSize=10,Font=Enum.Font.GothamSemibold,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
            local hpBarL=node("TextLabel",rowBg,{Size=UDim2.fromOffset(80,40),Position=UDim2.new(1,-126,0,0),BackgroundTransparency=1,Text="░░░░░░",TextColor3=C.faint,TextSize=8,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Right})
            local distL=node("TextLabel",rowBg,{Size=UDim2.fromOffset(48,40),Position=UDim2.new(1,-52,0,0),BackgroundTransparency=1,Text="—",TextColor3=C.muted,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Right})
            pad(distL,0,8,0,0)
            local btn=node("TextButton",rowBg,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",BorderSizePixel=0,AutoButtonColor=false})
            table.insert(RAVYN._connections,btn.MouseEnter:Connect(function() tw(rowBg,.12,{BackgroundColor3=C.raised}) end))
            table.insert(RAVYN._connections,btn.MouseLeave:Connect(function() tw(rowBg,.15,{BackgroundColor3=C.card}) end))
            table.insert(RAVYN._connections,btn.Activated:Connect(function()
                local name=rowBg:GetAttribute("NPCName"); local isBoss=rowBg:GetAttribute("NPCBoss")==true; if name and onClick then onClick(name,isBoss) end
            end))
            local function fill(x)
                rowBg.Visible=x~=nil
                if not x then return end
                rowBg:SetAttribute("NPCName",x.name)
                rowBg:SetAttribute("NPCBoss",x.isBoss==true)
                local isBoss=x.isBoss
                badgeL.Text=isBoss and "◆ BOSS" or "•  MOB"
                badgeL.TextColor3=isBoss and C.gold or C.faint
                nameL.Text=tostring(x.name)
                local hp=(x.health and x.maxHealth and x.maxHealth>0) and math.floor(x.health/x.maxHealth*100) or nil
                if hp then hpBarL.Text=hpBar(hp,6).." "..hp.."%"; hpBarL.TextColor3=hpColor(hp)
                else hpBarL.Text="░░░░░░"; hpBarL.TextColor3=C.faint end
                distL.Text=(x.distance and fmt(x.distance).." studs") or "—"
            end
            return rowBg,fill
        end

        -- Page setup
        local tabs={"Home","AutoPlay","Farm","Combat","Teleport","Automation","Settings","Lab"}
        local icons={Home="◆",AutoPlay="▶",Farm="◎",Combat="✦",Teleport="⌁",Automation="◇",Settings="⚙",Lab="⌘"}
        local pages={}; local pageGroups={}; local navButtons={}; local active="Home"

        local function show(name)
            if not pages[name] or name==active then return end
            local old=active; active=name; heading.Text=name
            local oldGroup=pageGroups[old]; local newGroup=pageGroups[name]
            if oldGroup then tw(oldGroup,.12,{GroupTransparency=1,Position=UDim2.fromOffset(-8,0)},Enum.EasingStyle.Quad,Enum.EasingDirection.Out); task.delay(.12,function() if oldGroup.Parent and active~=old then oldGroup.Visible=false end end) end
            newGroup.Visible=true; newGroup.GroupTransparency=1; newGroup.Position=UDim2.fromOffset(10,0); newGroup.Size=UDim2.fromScale(1,1)
            tw(newGroup,.22,{GroupTransparency=0,Position=UDim2.fromOffset(0,0)},Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
            pages[name].CanvasPosition=Vector2.new(0,0)
            for key,b in pairs(navButtons) do local sel=key==name; tw(b,.18,{BackgroundTransparency=sel and 0 or 1,BackgroundColor3=sel and C.raised or C.panel,TextColor3=sel and C.gold or C.muted}) end
        end

        for _,name in ipairs(tabs) do
            local group=node("CanvasGroup",pagesHost,{Size=UDim2.fromScale(1,1),Position=UDim2.fromOffset(0,0),BackgroundTransparency=1,GroupTransparency=(name=="Home") and 0 or 1,Visible=name=="Home"})
            pageGroups[name]=group; pages[name]=scroll(group)
            local b=node("TextButton",nav,{Size=UDim2.new(1,0,0,38),BackgroundColor3=C.panel,BackgroundTransparency=name=="Home" and 0 or 1,Text=(icons[name] or "•").."   "..name,TextColor3=name=="Home" and C.gold or C.muted,TextSize=10,Font=Enum.Font.GothamSemibold,TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0,AutoButtonColor=false})
            round(b,10); pad(b,10,0,0,0); navButtons[name]=b
            table.insert(RAVYN._connections,b.Activated:Connect(function() show(name) end))
        end
        table.insert(RAVYN._connections,search:GetPropertyChangedSignal("Text"):Connect(function()
            local q=string.lower(search.Text or "")
            for name,b in pairs(navButtons) do b.Visible=(q=="" or string.find(string.lower(name),q,1,true)~=nil) end
        end))

        -- ============================
        -- HOME PAGE
        -- ============================
        local hero=section(pages.Home,"RAVYN Intelligence","Current state, target and safety decisions update live.")

        -- HP status bar row
        local hpRow=node("Frame",hero,{Size=UDim2.new(1,0,0,40),BackgroundColor3=C.card,BorderSizePixel=0})
        round(hpRow,10)
        local hpLbl=node("TextLabel",hpRow,{Size=UDim2.fromOffset(26,40),Position=UDim2.fromOffset(12,0),BackgroundTransparency=1,Text="HP",TextColor3=C.muted,TextSize=9,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})
        local hpPctLbl=node("TextLabel",hpRow,{Size=UDim2.fromOffset(52,40),Position=UDim2.fromOffset(36,0),BackgroundTransparency=1,Text="100%",TextColor3=C.green,TextSize=20,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})
        local hpValLbl=node("TextLabel",hpRow,{Size=UDim2.fromOffset(110,40),Position=UDim2.fromOffset(88,0),BackgroundTransparency=1,Text="—/—",TextColor3=C.muted,TextSize=9,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left})
        local hpBarLblH=node("TextLabel",hpRow,{Size=UDim2.fromOffset(90,40),Position=UDim2.new(1,-96,0,0),BackgroundTransparency=1,Text="░░░░░░░░",TextColor3=C.green,TextSize=9,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Right})
        pad(hpBarLblH,0,8,0,0)
        table.insert(refreshers,function()
            local p=(RAVYN.Features.snapshot or {}).player or {}
            local pct=100
            if p.health and p.maxHealth and p.maxHealth>0 then pct=(p.health/p.maxHealth)*100 end
            local col=p.dead and C.red or hpColor(pct)
            hpPctLbl.Text=(p.dead and "DEAD") or (math.floor(pct+.5).."%")
            hpPctLbl.TextColor3=col
            hpValLbl.Text=(p.health and fmt(p.health) or "—").." / "..(p.maxHealth and fmt(p.maxHealth) or "—")
            hpBarLblH.Text=hpBar(p.dead and 0 or pct,8)
            hpBarLblH.TextColor3=col
        end)

        -- Target / mode dynamic
        dynamic(hero,function()
            local t=RAVYN.LiveAction.target
            local mode=RAVYN.LiveAction.positionMode
            local evading=RAVYN.LiveAction.evading
            local tStr=t and (tostring(t.name).."  ·  "..fmt(t.distance).." studs") or "No target"
            local mStr=(evading and "⚠ EVADING") or mode
            return "Target  "..tStr.."\nMotion  "..mStr.."  ·  "..tostring(RAVYN.LiveAction.lastMessage or "—")
        end,40,C.text,false)

        local autoHome=section(pages.Home,"Auto Play","One master switch. RAVYN chooses boss rotation or pre-farm, then drives the verified combat brain.")
        toggle(autoHome,"Auto Play",function() return RAVYN.Config.Intelligence.AutoPlay end,function(v) return RAVYN:SetAutoPlay(v) end,"Smart mode: boss available → rotate bosses · otherwise pre-farm",
            function() return RAVYN.Config.Intelligence.AutoPlay and "ACTIVE" or "READY",RAVYN.Config.Intelligence.AutoPlay and C.green or C.muted end)
        segmented(autoHome,{"Smart","Bosses","Mobs"},function() return RAVYN.Config.AutoPlayV38.Mode end,function(v) return RAVYN:SetAutoPlayMode(v) end)
        dynamic(autoHome,function()
            local a=RAVYN:GetAutoPlayStatus()
            return tostring(a.activity).."  ·  "..tostring(a.reason).."\nBrain  "..tostring(a.brain).."  ·  Risk "..string.format("%.0f",a.risk or 0).."%  ·  Bosses "..tostring(a.bossesDefeated or 0)
        end,38,C.text,false)

        local quick=section(pages.Home,"Quick controls","The switches below are actual live client actions.")
        toggle(quick,"Auto Farm",function() return RAVYN.Config.Farm.NormalMobs.Enabled end,function(v) return RAVYN:SetFeature("NORMAL_MOB",v) end,"Nearest normal mob · smart positioning",
            function() return RAVYN.Config.Farm.NormalMobs.Enabled and "ACTIVE" or "READY",RAVYN.Config.Farm.NormalMobs.Enabled and C.green or C.muted end)
        toggle(quick,"Auto Attack",function() return RAVYN.Config.Combat.AutoAttack end,function(v) return RAVYN:SetFeature("ATTACK",v) end,"M1 only when a target is in real attack range",
            function() return "LIVE",C.green end)
        toggle(quick,"Auto Skills",function() return RAVYN.Config.Combat.AutoAbilities end,function(v) return RAVYN:SetFeature("ABILITIES",v) end,"Cycles currently visible skill hotkeys",
            function() return "LIVE",C.green end)

        -- Prominent emergency stop
        local stopBtn=node("TextButton",pages.Home,{Size=UDim2.new(1,-3,0,46),BackgroundColor3=Color3.fromRGB(52,15,15),Text="⬛  Stop everything",TextColor3=C.red,TextSize=12,Font=Enum.Font.GothamBold,BorderSizePixel=0,AutoButtonColor=false})
        round(stopBtn,15); stroke(stopBtn,C.red,1,.70)
        table.insert(RAVYN._connections,stopBtn.MouseEnter:Connect(function() tw(stopBtn,.14,{BackgroundColor3=Color3.fromRGB(80,20,20)}) end))
        table.insert(RAVYN._connections,stopBtn.MouseLeave:Connect(function() tw(stopBtn,.18,{BackgroundColor3=Color3.fromRGB(52,15,15)}) end))
        table.insert(RAVYN._connections,stopBtn.Activated:Connect(function()
            RAVYN:SetAutoPlay(false); RAVYN:SetKillAura(false)
            RAVYN:SetFeature("NORMAL_MOB",false); RAVYN:SetFeature("BOSS",false)
            RAVYN:SetFeature("ATTACK",false); RAVYN:SetFeature("ABILITIES",false); RAVYN:Stop()
            notify("ALL STOPPED",true)
        end))

        local profileHome=section(pages.Home,"Smart profile","No manual tuning needed. Choose behavior, RAVYN handles distances and timing.")
        segmented(profileHome,{"Safe","Balanced","Aggressive"},function() return RAVYN.Config.SmartCombat.Profile end,function(v) return RAVYN:SetSmartProfile(v) end)

        -- ============================
        -- AUTO PLAY PAGE
        -- ============================
        local apMaster=section(pages.AutoPlay,"RAVYN Auto Play","Master orchestration over verified client actions. Unknown quest/loot/parry actions stay locked.")
        toggle(apMaster,"Auto Play",function() return RAVYN.Config.Intelligence.AutoPlay end,function(v) return RAVYN:SetAutoPlay(v) end,"One switch for target choice, movement, combat, safety and retargeting",
            function() return RAVYN.Config.Intelligence.AutoPlay and "RUNNING" or "READY",RAVYN.Config.Intelligence.AutoPlay and C.green or C.muted end)
        lbl(apMaster,"Strategy",18,9,C.muted,true)
        segmented(apMaster,{"Smart","Bosses","Mobs"},function() return RAVYN.Config.AutoPlayV38.Mode end,function(v) return RAVYN:SetAutoPlayMode(v) end)
        dynamic(apMaster,function()
            local a=RAVYN:GetAutoPlayStatus(); local t=a.target or "No target"
            return "Activity  "..tostring(a.activity).."\nTarget    "..tostring(t).."\nReason    "..tostring(a.reason)
        end,58,C.text,false)

        local apBehavior=section(pages.AutoPlay,"Behavior","Smart defaults. These settings change what the master switch is allowed to use.")
        toggle(apBehavior,"Boss rotation",function() return RAVYN.Config.AutoPlayV38.BossRotation end,function(v) return RAVYN:SetAutoPlayBossRotation(v) end,"After a boss is down, score and move to the next eligible streamed boss")
        toggle(apBehavior,"Pre-farm while bosses are unavailable",function() return RAVYN.Config.AutoPlayV38.PreFarm end,function(v) return RAVYN:SetAutoPlayPreFarm(v) end,"Smart mode keeps farming normal mobs instead of standing idle")
        toggle(apBehavior,"M1 combat",function() return RAVYN.Config.AutoPlayV38.AutoAttack end,function(v) return RAVYN:SetAutoPlayAttack(v) end,"Uses the verified client M1 path")
        toggle(apBehavior,"Smart skill combos",function() return RAVYN.Config.AutoPlayV38.AutoSkills end,function(v) return RAVYN:SetAutoPlaySkills(v) end,"Uses live SkillsHolder hotkeys with combo pacing")
        toggle(apBehavior,"Auto ESP",function() return RAVYN.Config.AutoPlayV38.AutoESP end,function(v) return RAVYN:SetAutoPlayESP(v) end,"Show streamed NPC + boss intelligence while Auto Play runs")

        local apSession=section(pages.AutoPlay,"Session","Live counters are evidence-bound; boss count increments only on an observed down transition.")
        dynamic(apSession,function()
            local a=RAVYN:GetAutoPlayStatus()
            return "Bosses defeated  "..tostring(a.bossesDefeated or 0).."\nRetargets         "..tostring(a.retargets or 0).."\nDamage rate       "..string.format("%.1f",a.damagePerSecond or 0).." /s"
        end,58,C.muted,false)
        lbl(apSession,"Stop after bosses",18,9,C.muted,true)
        local function stopLabel() local n=RAVYN.Config.AutoPlayV38.StopAfterBosses; return n==0 and "Never" or tostring(n) end
        segmented(apSession,{"Never","1","5","10"},stopLabel,function(v) return RAVYN:SetAutoPlayStopAfterBosses(v=="Never" and 0 or tonumber(v)) end)
        action(apSession,"Diagnose Auto Play Now",function() return RAVYN:DiagnoseAutoPlayNow() end,true)
        action(apSession,"Freeze State · 3s",function() return RAVYN:FreezeState(3) end,false)

        local apCapabilities=section(pages.AutoPlay,"Capability map","RAVYN never pretends an unresolved action is working.")
        dynamic(apCapabilities,function()
            return "Combat + movement     LIVE\nBoss rotation         LIVE\nSmart combo           LIVE\nRisk evade            LIVE\nQuest progression     NEEDS BINDING\nLoot / chest actions  NEEDS BINDING\nPerfect parry         EVIDENCE REQUIRED"
        end,110,C.muted,false)

        -- ============================
        -- FARM PAGE
        -- ============================
        local farmMode=section(pages.Farm,"Farm mode","Normal and Boss modes are mutually exclusive so movement never fights itself.")

        -- 3-option segmented: Normal / Boss / Off
        local farmSeg=node("Frame",farmMode,{Size=UDim2.new(1,0,0,40),BackgroundColor3=C.card,BorderSizePixel=0})
        round(farmSeg,11); pad(farmSeg,3,3,3,3)
        node("UIListLayout",farmSeg,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder})
        local farmSegBtns={}
        local farmSegItems={"Normal","Boss","Off"}
        for _,item in ipairs(farmSegItems) do
            local b=node("TextButton",farmSeg,{Size=UDim2.new(1/3,-3,1,0),BackgroundColor3=C.card,BackgroundTransparency=1,Text=item,TextColor3=C.muted,TextSize=10,Font=Enum.Font.GothamSemibold,BorderSizePixel=0,AutoButtonColor=false})
            round(b,9); farmSegBtns[item]=b
            table.insert(RAVYN._connections,b.Activated:Connect(function()
                if item=="Normal" then RAVYN:SetFeature("BOSS",false); RAVYN:SetFeature("NORMAL_MOB",true)
                elseif item=="Boss" then RAVYN:SetFeature("NORMAL_MOB",false); RAVYN:SetFeature("BOSS",true)
                else RAVYN:SetFeature("NORMAL_MOB",false); RAVYN:SetFeature("BOSS",false) end
                notify(item.." farm",true)
                local nOn=RAVYN.Config.Farm.NormalMobs.Enabled; local bOn=RAVYN.Config.Farm.Boss.Enabled
                local st={Normal=nOn,Boss=bOn,Off=not nOn and not bOn}
                for k,btn in pairs(farmSegBtns) do local ac=st[k]; tw(btn,.18,{BackgroundTransparency=ac and 0 or 1,BackgroundColor3=ac and C.raised or C.card,TextColor3=ac and C.text or C.muted}) end
            end))
        end
        local function refreshFarmSeg()
            local nOn=RAVYN.Config.Farm.NormalMobs.Enabled; local bOn=RAVYN.Config.Farm.Boss.Enabled
            local st={Normal=nOn,Boss=bOn,Off=not nOn and not bOn}
            for k,btn in pairs(farmSegBtns) do local ac=st[k]; btn.BackgroundTransparency=ac and 0 or 1; btn.BackgroundColor3=ac and C.raised or C.card; btn.TextColor3=ac and C.text or C.muted end
        end
        refreshFarmSeg(); table.insert(refreshers,refreshFarmSeg)

        -- Active target live display
        dynamic(farmMode,function()
            local t=RAVYN.LiveAction.target; if not t then return "Scanning for target…" end
            local hp=(t.health and t.maxHealth and t.maxHealth>0) and math.floor(t.health/t.maxHealth*100) or nil
            local badge=t.isBoss and "◆ BOSS" or "•  MOB"
            local hpStr=hp and ("  "..hpBar(hp,6).." "..hp.."%") or ""
            return badge.."  "..tostring(t.name)..hpStr.."  ·  "..fmt(t.distance).." studs"
        end,22,C.green,false)

        local farmIntel=section(pages.Farm,"Farm intelligence","Smart target rotation, local risk filters and range presets. No raw numbers required.")
        toggle(farmIntel,"Kill Aura",function() return RAVYN.Config.Intelligence.KillAura.Enabled end,function(v) return RAVYN:SetKillAura(v) end,"Uses the same target lock and combat brain; no competing attack loop",function() return RAVYN.Config.Intelligence.KillAura.Enabled and "ACTIVE" or "READY",RAVYN.Config.Intelligence.KillAura.Enabled and C.green or C.muted end)
        lbl(farmIntel,"Search radius",18,9,C.muted,true)
        segmented(farmIntel,{"Near","Normal","Wide","Stream"},function() return RAVYN.Config.Intelligence.SearchRadius end,function(v) return RAVYN:SetSearchRadiusPreset(v) end)
        lbl(farmIntel,"Kill Aura range",18,9,C.muted,true)
        segmented(farmIntel,{"Close","Normal","Wide"},function() return RAVYN.Config.Intelligence.KillAura.Range end,function(v) return RAVYN:SetConfig("Intelligence.KillAura.Range",v) end)
        toggle(farmIntel,"Kill Aura follows target",function() return RAVYN.Config.Intelligence.KillAura.Follow end,function(v) return RAVYN:SetConfig("Intelligence.KillAura.Follow",v) end,"Off = attack nearby only · On = follow within selected aura range")
        lbl(farmIntel,"Risk filter",18,9,C.muted,true)
        segmented(farmIntel,{"Safe","Balanced","Any"},function() return RAVYN.Config.Intelligence.TargetRules.RiskMode end,function(v) return RAVYN:SetConfig("Intelligence.TargetRules.RiskMode",v) end)
        dynamic(farmIntel,function() local bosses=0; local live=0; for _,m in pairs(RAVYN.Brain.bossMemory or {}) do bosses+=1; if m.alive then live+=1 end end; return "Boss rotation  "..live.." alive / "..bosses.." observed  ·  target stickiness ON" end,20,C.muted,false)

        local farmCombat=section(pages.Farm,"Smart combat","RAVYN changes angle automatically and escapes upward when health is low.")
        segmented(farmCombat,{"Safe","Balanced","Aggressive"},function() return RAVYN.Config.SmartCombat.Profile end,function(v) return RAVYN:SetSmartProfile(v) end)
        lbl(farmCombat,"Positioning",18,9,C.muted,true)
        segmented(farmCombat,{"Smart","Behind","Orbit","Above"},function() return RAVYN.Config.SmartCombat.Positioning end,function(v) return RAVYN:SetSmartPosition(v) end)
        dynamic(farmCombat,function()
            local s=RAVYN.Config.SmartCombat
            return "Safety · evade ≤"..s.LowHealthPercent.."% · critical ≤"..s.CriticalHealthPercent.."% · resume ≥"..s.RecoveryPercent.."%"
        end,20,C.muted,false)

        -- NPC picker — richer rows with HP bar, type badge, distance
        local farmPicker=section(pages.Farm,"Target picker","Tap a live NPC. Shows type, health and distance. Search filters by name.")
        local farmSearch=node("TextBox",farmPicker,{Size=UDim2.new(1,0,0,34),BackgroundColor3=C.card,Text="",PlaceholderText="Search NPCs by name…",PlaceholderColor3=C.faint,TextColor3=C.text,TextSize=10,Font=Enum.Font.Gotham,ClearTextOnFocus=false,BorderSizePixel=0})
        round(farmSearch,9)
        local farmPredict=lbl(farmPicker,"Showing nearest streamed NPCs",18,9,C.faint,false)
        local function activeFarmKind()
            if RAVYN.Config.Farm.Boss.Enabled then return "BOSS" end
            if RAVYN.Config.Farm.NormalMobs.Enabled then return "MOB" end
            return "ALL"
        end
        local function setFarmTargetForMode(name,isBoss)
            local boss=RAVYN.Config.Farm.Boss.Enabled or (not RAVYN.Config.Farm.NormalMobs.Enabled and isBoss==true)
            return RAVYN:SetFarmTarget(name,boss)
        end
        action(farmPicker,"Any / nearest",function()
            farmSearch.Text=""
            return RAVYN:SetFarmTarget("Any",RAVYN.Config.Farm.Boss.Enabled)
        end,true)
        local farmFills={}
        for i=1,6 do
            local _,fillFn=npcRow(farmPicker,function(name,isBoss)
                farmSearch.Text=name
                local r=setFarmTargetForMode(name,isBoss)
                notify(r.code,r.ok)
            end)
            farmFills[i]=fillFn
        end
        local function refreshFarmPicker()
            local kind=activeFarmKind()
            local list=RAVYN:GetObservedNPCs(kind,6,farmSearch.Text)
            local label=kind=="BOSS" and "nearest streamed bosses" or (kind=="MOB" and "nearest streamed mobs" or "nearest streamed NPCs")
            farmPredict.Text=(farmSearch.Text~="" and list[1]) and ("→ "..tostring(list[1].name)) or ("Showing "..label)
            for i,fillFn in ipairs(farmFills) do fillFn(list[i]) end
        end
        table.insert(refreshers,refreshFarmPicker)
        table.insert(RAVYN._connections,farmSearch:GetPropertyChangedSignal("Text"):Connect(refreshFarmPicker))
        table.insert(RAVYN._connections,farmSearch.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local list=RAVYN:GetObservedNPCs(activeFarmKind(),1,farmSearch.Text)
                if list[1] then
                    farmSearch.Text=list[1].name
                    local r=setFarmTargetForMode(list[1].name,list[1].isBoss)
                    notify(r.code,r.ok)
                end
            end
        end))

        -- ============================
        -- COMBAT PAGE
        -- ============================
        local combat=section(pages.Combat,"Combat engine","Farm movement and combat share one target lock, so inputs do not fight each other.")
        toggle(combat,"Auto Attack · M1",function() return RAVYN.Config.Combat.AutoAttack end,function(v) return RAVYN:SetFeature("ATTACK",v) end,"Disabled automatically while emergency evade is active",function() return "LIVE",C.green end)
        toggle(combat,"Auto Skills",function() return RAVYN.Config.Combat.AutoAbilities end,function(v) return RAVYN:SetFeature("ABILITIES",v) end,"Uses verified SkillsHolder hotkeys",function() return "LIVE",C.green end)
        toggle(combat,"Smart safety",function() return RAVYN.Config.SmartCombat.Enabled end,function(v) return RAVYN:SetConfig("SmartCombat.Enabled",v) end,"Low HP → move above target and stop risky M1",function() return "LIVE",C.green end)
        segmented(combat,{"Safe","Balanced","Aggressive"},function() return RAVYN.Config.SmartCombat.Profile end,function(v) return RAVYN:SetSmartProfile(v) end)
        toggle(combat,"Smart combo planner",function() return RAVYN.Config.Intelligence.CombatBrain.SmartCombo end,function(v) return RAVYN:SetConfig("Intelligence.CombatBrain.SmartCombo",v) end,"M1 weave → skill → reposition; visible skill hotkeys only",function() return "LIVE",C.green end)
        lbl(combat,"Attack range",18,9,C.muted,true)
        segmented(combat,{"Close","Normal","Wide"},function() return RAVYN.Config.Intelligence.CombatBrain.AttackRange end,function(v) return RAVYN:SetConfig("Intelligence.CombatBrain.AttackRange",v) end)
        lbl(combat,"Skill tempo",18,9,C.muted,true)
        segmented(combat,{"Careful","Normal","Fast"},function() return RAVYN.Config.Intelligence.CombatBrain.SkillTempo end,function(v) return RAVYN:SetConfig("Intelligence.CombatBrain.SkillTempo",v) end)
        lbl(combat,"Distance from target",18,9,C.muted,true)
        segmented(combat,{"Close","Normal","Safe"},function() return RAVYN.Config.Intelligence.CombatBrain.Distance end,function(v) return RAVYN:SetConfig("Intelligence.CombatBrain.Distance",v) end)
        lbl(combat,"Travel mode",18,9,C.muted,true)
        local function travelModeName()
            if RAVYN.Config.SmartCombat.AdaptiveTravel then return "Smart" end
            return RAVYN.Config.Movement.TravelMode=="Teleport" and "Teleport" or "Tween"
        end
        segmented(combat,{"Smart","Tween","Teleport"},travelModeName,function(v)
            if v=="Smart" then RAVYN:SetConfig("Movement.TravelMode","Tween"); return RAVYN:SetConfig("SmartCombat.AdaptiveTravel",true)
            elseif v=="Tween" then RAVYN:SetConfig("SmartCombat.AdaptiveTravel",false); return RAVYN:SetConfig("Movement.TravelMode","Tween")
            else RAVYN:SetConfig("SmartCombat.AdaptiveTravel",false); return RAVYN:SetConfig("Movement.TravelMode","Teleport") end
        end)
        lbl(combat,"Travel speed",18,9,C.muted,true)
        segmented(combat,{"Careful","Normal","Fast"},function() return RAVYN.Config.Intelligence.CombatBrain.TravelSpeed end,function(v) return RAVYN:SetConfig("Intelligence.CombatBrain.TravelSpeed",v) end)

        local mobility=section(pages.Combat,"Combat mobility","Flight owns movement while farming/fighting so RAVYN stays level with the target instead of teleporting or fighting tweens.")
        toggle(mobility,"Fly during farm / fight",function() return RAVYN.Config.CombatMobility and RAVYN.Config.CombatMobility.FlyFarmFight end,function(v) return RAVYN:SetConfig("CombatMobility.FlyFarmFight",v) end,"Keeps a controlled air offset from the active target",function() return (RAVYN.CombatMobility and RAVYN.CombatMobility.flightActive) and "FLYING" or "READY",(RAVYN.CombatMobility and RAVYN.CombatMobility.flightActive) and C.green or C.muted end)
        toggle(mobility,"No combat teleport",function() return RAVYN.Config.CombatMobility and RAVYN.Config.CombatMobility.NoCombatTeleport end,function(v) return RAVYN:SetConfig("CombatMobility.NoCombatTeleport",v) end,"Combat movement is handled by flight; teleport remains available outside combat")
        lbl(mobility,"Flight height",18,9,C.muted,true)
        segmented(mobility,{"Low","Normal","High"},function() local h=RAVYN.Config.CombatMobility and RAVYN.Config.CombatMobility.FlyHeight or 5.5; return h<=3.8 and "Low" or (h>=8 and "High" or "Normal") end,function(v) local map={Low=3.0,Normal=5.5,High=9.0}; return RAVYN:SetConfig("CombatMobility.FlyHeight",map[v] or 5.5) end)
        toggle(mobility,"Turbo M1",function() return RAVYN.Config.CombatMobility and RAVYN.Config.CombatMobility.TurboM1 end,function(v) return RAVYN:SetConfig("CombatMobility.TurboM1",v) end,"High-frequency M1 loop; still respects combat/skill/defense locks",function() return "TURBO",C.gold end)
        toggle(mobility,"Aggressive skills",function() return RAVYN.Config.CombatMobility and RAVYN.Config.CombatMobility.AggressiveSkills end,function(v) return RAVYN:SetConfig("CombatMobility.AggressiveSkills",v) end,"Uses discovered visible skill keys frequently instead of waiting ~2 seconds",function() return "ROTATION",C.green end)
        toggle(mobility,"Keep combo while hit",function() return RAVYN.Config.CombatMobility and RAVYN.Config.CombatMobility.KeepComboUnderHit end,function(v) return RAVYN:SetConfig("CombatMobility.KeepComboUnderHit",v) end,"Damage alone will not force the combat brain into emergency evade")
        toggle(mobility,"Anti Ragdoll",function() return RAVYN.Config.CombatMobility and RAVYN.Config.CombatMobility.AntiRagdoll end,function(v) return RAVYN:SetConfig("CombatMobility.AntiRagdoll",v) end,"Immediately requests GettingUp/Running and removes local angular ragdoll")
        toggle(mobility,"Anti Stun · experimental",function() return RAVYN.Config.CombatMobility and RAVYN.Config.CombatMobility.AntiStun end,function(v) return RAVYN:SetConfig("CombatMobility.AntiStun",v) end,"Best-effort local recovery from discovered stun/ragdoll flags; server state may reapply it",function() return "CLIENT",C.gold end)
        dynamic(mobility,function() local r=RAVYN.GetCombatMobilityStatus and RAVYN:GetCombatMobilityStatus(); local v=r and r.value or {}; return "Flight  "..tostring(v.flightActive and "ACTIVE" or "standby").."  ·  M1 "..tostring(v.m1Count or 0).."  ·  Skills "..tostring(v.skillCount or 0).."\nControl recoveries  "..tostring(v.recoveries or 0).."  ·  last "..tostring(v.lastAction or "—") end,40,C.text,false)

        local defense=section(pages.Combat,"Combat evolution","Keeps your character facing the target, learns dangerous attacks, dodges them and evolves skill order from observed damage.")
        toggle(defense,"Face target lock",function() return RAVYN.Config.CombatEvolution and RAVYN.Config.CombatEvolution.FaceLock end,function(v) return RAVYN:SetConfig("CombatEvolution.FaceLock",v) end,"Character faces the active target before M1, heavy and skills",function() return "LIVE",C.green end)
        toggle(defense,"Adaptive dodge",function() return RAVYN.Config.CombatEvolution and RAVYN.Config.CombatEvolution.Defense.AdaptiveDodge end,function(v) return RAVYN:SetConfig("CombatEvolution.Defense.AdaptiveDodge",v) end,"Learns enemy animation → damage timing; unknown animations get a soft sidestep",function() return "LEARNING",C.gold end)
        toggle(defense,"Reactive guard",function() return RAVYN.Config.CombatEvolution and RAVYN.Config.CombatEvolution.Defense.ReactiveGuard end,function(v) return RAVYN:SetConfig("CombatEvolution.Defense.ReactiveGuard",v) end,"Holds a verified/non-conflicting block key after hits or very late learned threats",function()
            local s=RAVYN:GetCombatEvolutionStatus(); local v=s and s.value or {}; return v.guardKey and ("GUARD "..tostring(v.guardKey)) or "AUTO",v.guardKey and C.green or C.muted
        end)
        toggle(defense,"Heavy combo finisher",function() return RAVYN.Config.CombatEvolution and RAVYN.Config.CombatEvolution.UseHeavyAttack end,function(v) return RAVYN:SetConfig("CombatEvolution.UseHeavyAttack",v) end,"Adds M2 finishers after pressure strings instead of M1-only combat",function() return "LIVE",C.green end)
        toggle(defense,"Learn skill damage",function() return RAVYN.Config.CombatEvolution and RAVYN.Config.CombatEvolution.Learning.Enabled end,function(v) return RAVYN:SetConfig("CombatEvolution.Learning.Enabled",v) end,"Observes target HP drop after each skill and gradually prioritizes better-performing skills",function() return "ADAPTIVE",C.gold end)
        dynamic(defense,function()
            local r=RAVYN:GetCombatEvolutionStatus(); local v=r and r.value or {}; local top=v.topSkill
            local skill=top and (tostring(top.key).." · avg "..string.format("%.1f",top.avgDamage or 0).."%") or "learning"
            return "Defense  "..tostring(v.status or "READY").."\nThreats  "..tostring(v.learnedThreats or 0).." / "..tostring(v.observedAnimations or 0).." observed  ·  Guard "..tostring(v.guardKey or v.guardSource or "unresolved").."\nBest skill  "..skill
        end,56,C.text,false)

        -- Live decision card: big HP + position mode chip
        local combatStatus=section(pages.Combat,"Live decision","Shows what RAVYN is doing right now.")
        local hpCard=node("Frame",combatStatus,{Size=UDim2.new(1,0,0,56),BackgroundColor3=C.card,BorderSizePixel=0})
        round(hpCard,12)
        local hpBig=node("TextLabel",hpCard,{Size=UDim2.fromOffset(100,56),Position=UDim2.fromOffset(14,0),BackgroundTransparency=1,Text="100%",TextColor3=C.green,TextSize=30,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left})
        local hpBarBig=node("TextLabel",hpCard,{Size=UDim2.fromOffset(140,56),Position=UDim2.fromOffset(114,0),BackgroundTransparency=1,Text="██████████",TextColor3=C.green,TextSize=11,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left})
        local posChip=node("Frame",hpCard,{Size=UDim2.fromOffset(96,24),Position=UDim2.new(1,-106,0.5,-12),BackgroundColor3=C.goldDim,BorderSizePixel=0})
        round(posChip,10)
        local posLbl=node("TextLabel",posChip,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="IDLE",TextColor3=C.gold,TextSize=8,Font=Enum.Font.GothamBold})
        table.insert(refreshers,function()
            local p=(RAVYN.Features.snapshot or {}).player or {}
            local pct=100
            if p.health and p.maxHealth and p.maxHealth>0 then pct=(p.health/p.maxHealth)*100 end
            local col=p.dead and C.red or hpColor(pct)
            hpBig.Text=(p.dead and "DEAD") or (math.floor(pct+.5).."%")
            hpBig.TextColor3=col; hpBarBig.Text=hpBar(p.dead and 0 or pct,10); hpBarBig.TextColor3=col
            local mode=RAVYN.LiveAction.positionMode; local evading=RAVYN.LiveAction.evading
            posLbl.Text=mode
            if evading then posChip.BackgroundColor3=Color3.fromRGB(68,18,18); posLbl.TextColor3=C.red
            elseif mode=="IDLE" then posChip.BackgroundColor3=C.card; posLbl.TextColor3=C.faint
            else posChip.BackgroundColor3=C.goldDim; posLbl.TextColor3=C.gold end
        end)
        dynamic(combatStatus,function()
            local t=RAVYN.LiveAction.target; local src=RAVYN.LiveAction.lastInputSource
            local risk=t and select(1,RAVYN:GetRiskRating(t)) or "—"
            return "Target  "..(t and (tostring(t.name).."  ·  "..fmt(t.distance).." studs  ·  "..risk) or "No target").."\nBrain   "..tostring(RAVYN.Brain.state).."  ·  "..tostring(RAVYN.Brain.combo.lastAction or "—").."\nInput    "..(src or "—")
        end,58,C.text,false)
        action(combatStatus,"Test M1 once",function() return RAVYN:ClientAttack() end,true)
        action(combatStatus,"Test next skill",function() return RAVYN:ClientSkill() end,false)

        -- ============================
        -- TELEPORT PAGE
        -- ============================
        local tp=section(pages.Teleport,"Smart NPC Teleport","No exact typing required. Pick from live NPCs or type a few letters.")
        local tpSearch=node("TextBox",tp,{Size=UDim2.new(1,0,0,34),BackgroundColor3=C.card,Text="",PlaceholderText="Search a few letters…",PlaceholderColor3=C.faint,TextColor3=C.text,TextSize=10,Font=Enum.Font.Gotham,ClearTextOnFocus=false,BorderSizePixel=0})
        round(tpSearch,9)
        local tpPredict=lbl(tp,"Showing nearest streamed NPCs",18,9,C.faint,false)
        action(tp,"Teleport to nearest",function() return RAVYN:TeleportToNPC("nearest") end,true)
        local tpFills={}
        for i=1,7 do
            local _,fillFn=npcRow(tp,function(name)
                tpSearch.Text=name; local r=RAVYN:TeleportToNPC(name); notify(r.code,r.ok)
            end)
            tpFills[i]=fillFn
        end
        local function refreshTeleportPicker()
            local list=RAVYN:GetObservedNPCs("ALL",7,tpSearch.Text)
            tpPredict.Text=(tpSearch.Text~="" and list[1]) and ("→ "..tostring(list[1].name)) or "Showing nearest streamed NPCs"
            for i,fillFn in ipairs(tpFills) do fillFn(list[i]) end
        end
        table.insert(refreshers,refreshTeleportPicker)
        table.insert(RAVYN._connections,tpSearch:GetPropertyChangedSignal("Text"):Connect(refreshTeleportPicker))
        table.insert(RAVYN._connections,tpSearch.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local list=RAVYN:GetObservedNPCs("ALL",1,tpSearch.Text)
                if list[1] then tpSearch.Text=list[1].name; local r=RAVYN:TeleportToNPC(list[1].name); notify(r.code,r.ok) end
            end
        end))

        local savedPlaces=section(pages.Teleport,"Saved places","One-tap local positions. Public map destinations stay locked until their world positions are verified.")
        action(savedPlaces,"Save current location",function() return RAVYN:SaveCurrentPlace() end,true)
        local placeButtons={}
        for i=1,5 do
            local idx=i
            local b=node("TextButton",savedPlaces,{Size=UDim2.new(1,0,0,34),BackgroundColor3=C.card,Text="",TextColor3=C.text,TextSize=10,Font=Enum.Font.GothamSemibold,TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0,Visible=false,AutoButtonColor=false})
            round(b,10); pad(b,10,10,0,0); b:SetAttribute("PlaceIndex",idx)
            table.insert(RAVYN._connections,b.MouseEnter:Connect(function() tw(b,.12,{BackgroundColor3=C.raised}) end)); table.insert(RAVYN._connections,b.MouseLeave:Connect(function() tw(b,.15,{BackgroundColor3=C.card}) end))
            table.insert(RAVYN._connections,b.Activated:Connect(function() local r=RAVYN:TeleportToSavedPlace(b:GetAttribute("PlaceIndex")); notify(r.code,r.ok) end)); placeButtons[i]=b
        end
        table.insert(refreshers,function() local list=RAVYN.Config.Intelligence.SavedPlaces or {}; for i,b in ipairs(placeButtons) do local x=list[i]; b.Visible=x~=nil; b.Text=x and ("⌂  "..tostring(x.name)) or "" end end)
        action(savedPlaces,"Clear saved places",function() return RAVYN:ClearSavedPlaces() end,false)
        dynamic(savedPlaces,function() return "Public places  ·  NEEDS VERIFIED WORLD POSITION EVIDENCE" end,18,C.faint,false)

        -- ============================
        -- AUTOMATION PAGE
        -- ============================
        local liveAuto=section(pages.Automation,"Working now","Only actions with a real client implementation appear as switches.")
        toggle(liveAuto,"Normal Mob Farm",function() return RAVYN.Config.Farm.NormalMobs.Enabled end,function(v) return RAVYN:SetFeature("NORMAL_MOB",v) end,nil,function() return "LIVE",C.green end)
        toggle(liveAuto,"Boss Farm",function() return RAVYN.Config.Farm.Boss.Enabled end,function(v) return RAVYN:SetFeature("BOSS",v) end,nil,function() return "LIVE",C.green end)
        toggle(liveAuto,"Auto Attack",function() return RAVYN.Config.Combat.AutoAttack end,function(v) return RAVYN:SetFeature("ATTACK",v) end,nil,function() return "LIVE",C.green end)
        toggle(liveAuto,"Auto Skills",function() return RAVYN.Config.Combat.AutoAbilities end,function(v) return RAVYN:SetFeature("ABILITIES",v) end,nil,function() return "LIVE",C.green end)
        toggle(liveAuto,"Move Speed",function() return RAVYN.Config.Movement.SpeedEnabled end,function(v) return RAVYN:SetFeature("SPEED",v) end,nil,function() return "LIVE",C.green end)
        toggle(liveAuto,"Kill Aura",function() return RAVYN.Config.Intelligence.KillAura.Enabled end,function(v) return RAVYN:SetKillAura(v) end,nil,function() return "LIVE",C.green end)
        toggle(liveAuto,"NPC ESP",function() return RAVYN.Config.Intelligence.ESP.NPC end,function(v) return RAVYN:SetESP("NPC",v) end,nil,function() return "LOCAL",C.blue end)
        toggle(liveAuto,"Boss ESP",function() return RAVYN.Config.Intelligence.ESP.Boss end,function(v) return RAVYN:SetESP("Boss",v) end,nil,function() return "LOCAL",C.gold end)
        toggle(liveAuto,"Anti-AFK",function() return RAVYN.Config.Intelligence.AntiAFK end,function(v) return RAVYN:SetAntiAFK(v) end,nil,function() return "LOCAL",C.green end)

        local targetRules=section(pages.Automation,"Target rules","Client-side safety filters applied before combat target acquisition.")
        toggle(targetRules,"Skip civilians / trainers",function() return RAVYN.Config.Intelligence.TargetRules.SkipCivilians end,function(v) return RAVYN:SetConfig("Intelligence.TargetRules.SkipCivilians",v) end)
        toggle(targetRules,"Skip bosses rated Too Strong",function() return RAVYN.Config.Intelligence.TargetRules.SkipBossTooStrong end,function(v) return RAVYN:SetConfig("Intelligence.TargetRules.SkipBossTooStrong",v) end)
        action(targetRules,"Never attack current target",function() local t=RAVYN.LiveAction.target; if not t then return result(false,"NO_TARGET") end; return RAVYN:AddNeverAttack(t.name) end)
        action(targetRules,"Clear Never Attack list",function() return RAVYN:ClearNeverAttack() end)
        action(targetRules,"Reset damage & risk measures",function() return RAVYN:ResetRiskMeasures() end,true)

        -- Locked features displayed as compact two-column text list
        local lockedSec=section(pages.Automation,"Awaiting binding","These unlock only after the exact game action binding is verified. Not fake toggles.")
        local lockedList=lbl(lockedSec,"",0,8,C.faint,false)
        lockedList.AutomaticSize=Enum.AutomaticSize.Y
        lockedList.Size=UDim2.new(1,0,0,0)
        table.insert(refreshers,function()
            RAVYN.Registry:refresh()
            local names={}
            for _,f in ipairs(RAVYN.Registry.order) do
                if RAVYN:GetFeatureActionStatus(f.id)~="LIVE" then table.insert(names,"◇  "..f.name) end
            end
            -- Two columns side by side in text
            local rows={}
            local i=1
            while i<=#names do
                local left=names[i] or ""; local right=names[i+1] or ""
                table.insert(rows,left..string.rep(" ",math.max(1,36-#left))..right)
                i+=2
            end
            lockedList.Text=table.concat(rows,"\n")
        end)

        -- ============================
        -- SETTINGS PAGE
        -- ============================
        local settings=section(pages.Settings,"Interface","Compact window, local persistence and smooth motion.")
        toggle(settings,"Remember settings",function() return RAVYN.Config.UI.RememberSettings end,function(v) return RAVYN:SetConfig("UI.RememberSettings",v) end,"Saved only through executor-local file APIs")
        action(settings,"Save settings",function() return RAVYN:SaveSettings() end,true)
        action(settings,"Reload settings",function() return RAVYN:LoadSettings() end)
        action(settings,"Delete saved settings",function() return RAVYN:DeleteSavedSettings() end)

        local speed=section(pages.Settings,"Movement feel","Presets instead of raw numbers.")
        local function speedName() local v=RAVYN.Config.Movement.Speed; if v<=17 then return "Normal" elseif v<=23 then return "Swift" else return "Fast" end end
        segmented(speed,{"Normal","Swift","Fast"},speedName,function(v)
            local map={Normal=16,Swift=22,Fast=28}; local r=RAVYN:SetConfig("Movement.Speed",map[v])
            if r.ok then RAVYN:SetConfig("Movement.SpeedEnabled",v~="Normal") end; return r
        end)

        local advanced=section(pages.Settings,"Advanced","Raw configuration stays available for diagnostics, but everyday use should not need it.")
        action(advanced,"Save runtime report file",function() return RAVYN:SaveRuntimeReport() end)
        action(advanced,"Clear old logs",function() return RAVYN:ClearRuntimeLogs() end)
        action(advanced,"Open Binding Lab",function() show("Lab"); return result(true,"LAB_OPENED") end)
        action(advanced,"Unload RAVYN",function() task.defer(function() RAVYN:Destroy() end); return result(true,"UNLOADING") end)
        dynamic(advanced,function() return "Build · "..tostring(RAVYN.Build).."\nVersion · "..tostring(RAVYN.Version) end,42,C.faint,false)

        -- ============================
        -- LAB PAGE
        -- ============================
        local lab=section(pages.Lab,"Binding Lab","Read/capture tools remain non-destructive. Live client actions are isolated from discovery.")
        action(lab,"Run Live Read Scan",function() return RAVYN:RunLiveReadScan() end,true)
        action(lab,"Copy Binding Report",function() return RAVYN:CopyProbeReport("Binding") end)
        action(lab,"Capture Quest · Before",function() return RAVYN:CaptureProbe("Quest","Before") end)
        action(lab,"Capture Quest · After",function() return RAVYN:CaptureProbe("Quest","After") end)
        action(lab,"Compare Quest State",function() return RAVYN:CompareQuestState() end)
        action(lab,"Copy Quest Diff",function() return RAVYN:CopyProbeReport("Quest") end)
        action(lab,"Capture Combat · Idle",function() return RAVYN:CaptureProbe("Combat","Idle") end)
        action(lab,"Capture Combat · Target",function() return RAVYN:CaptureProbe("Combat","Target") end)
        action(lab,"Capture Combat · Attack",function() return RAVYN:CaptureProbe("Combat","Attack") end)
        action(lab,"Capture Combat · Kill",function() return RAVYN:CaptureProbe("Combat","Kill") end)
        action(lab,"Compare Combat",function() return RAVYN:CompareCombat() end)
        action(lab,"Copy Combat Diff",function() return RAVYN:CopyProbeReport("Combat") end)
        action(lab,"Watch Quest Signals · 60s",function() return RAVYN.Probes:watchQuest(60,1.5) end,true)
        action(lab,"Watch Combat Signals · 60s",function() return RAVYN.Probes:watchCombat(60,.05) end,true)
        action(lab,"Stop Signal Watches",function()
            pcall(function() RAVYN.Probes:stopQuestWatch() end); pcall(function() RAVYN.Probes:stopCombatWatch() end)
            return {ok=true,code="WATCHES_STOPPED",message="WATCHES_STOPPED"}
        end)
        action(lab,"Quest Signal Report",function() local r=RAVYN:GetQuestSignalReport(); RAVYN.ProbeReport=serialize(r.value); return r end)
        action(lab,"Combat Signal Report",function() local r=RAVYN:GetCombatSignalReport(); RAVYN.ProbeReport=serialize(r.value); return r end)
        action(lab,"Adaptive Intelligence Status",function() return RAVYN.GetAdaptiveIntelligenceStatus and RAVYN:GetAdaptiveIntelligenceStatus() or {ok=false,code="ADAPTIVE_NOT_INSTALLED"} end)
        action(lab,"Universal Quest Status",function() return RAVYN.GetUniversalQuestStatus and RAVYN:GetUniversalQuestStatus() or {ok=false,code="QUEST_BRAIN_NOT_INSTALLED"} end)

        local parryLab=section(pages.Lab,"Perfect Parry Lab","Evidence capture only. Auto Parry remains locked until a reliable incoming-attack / impact-window signal is confirmed.")
        action(parryLab,"Capture Enemy · Idle",function() return RAVYN:CaptureParryEvidence("ParryIdle") end)
        action(parryLab,"Capture Enemy · Windup",function() return RAVYN:CaptureParryEvidence("ParryWindup") end)
        action(parryLab,"Capture Successful Block",function() return RAVYN:CaptureParryEvidence("ParrySuccess") end)
        action(parryLab,"Capture Hit Taken",function() return RAVYN:CaptureParryEvidence("ParryHit") end)
        action(parryLab,"Compare Parry Evidence",function() return RAVYN:CompareParryEvidence() end)

        local report=section(pages.Lab,"Last report","Selectable text for executors without clipboard support.")
        local reportBox=node("TextBox",report,{Size=UDim2.new(1,0,0,220),Text=RAVYN.ProbeReport,MultiLine=true,TextEditable=false,ClearTextOnFocus=false,TextColor3=C.muted,BackgroundColor3=C.card,TextSize=9,Font=Enum.Font.Code,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,BorderSizePixel=0})
        round(reportBox,10); pad(reportBox,8,8,8,8)
        table.insert(refreshers,function() if reportBox.Text~=RAVYN.ProbeReport then reportBox.Text=RAVYN.ProbeReport end end)

        local logs=section(pages.Lab,"Runtime log","Newest events")
        dynamic(logs,function()
            local out={}; local entries=RAVYN.Logger.entries
            for i=math.max(1,#entries-24),#entries do local x=entries[i]; table.insert(out,x.level.."  ·  "..x.message) end
            return table.concat(out,"\n")
        end,220,C.faint,false)

        -- Live UI refresh loop
        task.spawn(function()
            while not RAVYN._destroyed and RAVYN._gui==gui do
                RAVYN.Registry:refresh()
                for _,refresh in ipairs(refreshers) do
                    local s,e=pcall(refresh)
                    if not s then RAVYN.Logger:log("WARN","UI_REFRESH_FAILED",{error=tostring(e)}) end
                end
                task.wait(.45)
            end
        end)
    end)
    if not ok then RAVYN.Logger:log("WARN","UI mount failed",{error=tostring(err)}) end
end
CTX["mountUI"]=mountUI
return true]==========]); if not ok then return end end
do local ok=runChunk("SignalExtractorV381.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Logger=CTX["Logger"]
local Config=CTX["Config"]
local FSM=CTX["FSM"]
local distance=CTX["distance"]
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local v3=CTX["v3"]
local Brain=CTX["Brain"]
local AutoPlay38=CTX["AutoPlay38"]
-- RAVYN v3.8.1 Signal Extractor
-- Passive evidence pipeline for Quest / Combat / Parry discovery.
-- Designed to be executed AFTER RAVYN v3.8 Auto Play.
-- No RemoteEvent/RemoteFunction invocation. No ProximityPrompt firing. No guessed action binding.

local env=(getgenv and getgenv()) or _G
if type(RAVYN)~="table" or type(RAVYN.Probes)~="table" or type(RAVYN.ReadAdapter)~="table" then
    error("RAVYN probe/read adapter unavailable")
end

local function result(ok,code,value,metadata)
    return {ok=ok,code=code or (ok and "OK" or "ERROR"),message=code or (ok and "OK" or "ERROR"),retryable=false,value=value,metadata=metadata or {}}
end
local function service(name)
    local ok,v=pcall(function() return game:GetService(name) end)
    return ok and v or nil
end
local function prop(obj,key)
    local ok,v=pcall(function() return obj and obj[key] end)
    return ok and v or nil
end
local function pathOf(inst)
    if not inst then return "<nil>" end
    local parts={}; local cur=inst; local guard=0
    while cur and cur~=game and guard<80 do
        table.insert(parts,1,tostring(prop(cur,"Name") or "?")); cur=prop(cur,"Parent"); guard+=1
    end
    return "game."..table.concat(parts,".")
end
local function isA(inst,class)
    local ok,v=pcall(function() return inst:IsA(class) end)
    return ok and v or false
end
local function attrs(inst)
    local ok,v=pcall(function() return inst:GetAttributes() end)
    return ok and v or {}
end
local function descendants(root,limit)
    if not root then return {},false end
    local ok,list=pcall(function() return root:GetDescendants() end)
    if not ok then return {},false end
    local cut=#list>(limit or 2500); local out={}
    for i=1,math.min(#list,limit or 2500) do out[i]=list[i] end
    return out,cut
end
local function scalar(v)
    local t=typeof and typeof(v) or type(v)
    if t=="string" or t=="number" or t=="boolean" then return v end
    if t=="Vector3" then return string.format("%.3f,%.3f,%.3f",v.X,v.Y,v.Z) end
    if t=="UDim2" then return tostring(v) end
    return nil
end
local function median(list)
    if #list==0 then return nil end
    local copy={}; for i,v in ipairs(list) do copy[i]=v end
    table.sort(copy)
    local n=#copy
    if n%2==1 then return copy[(n+1)/2] end
    return (copy[n/2]+copy[n/2+1])/2
end
local function round(n,p)
    local m=10^(p or 2); return math.floor(n*m+.5)/m
end
local function containsWord(text,words)
    local s=string.lower(tostring(text or ""))
    for _,w in ipairs(words) do if string.find(s,w,1,true) then return true end end
    return false
end
local QUEST_WORDS={"quest","mission","objective","progress","required","complete","target","kill","defeat","amount","goal","reward","hunt","collect","breath"}

local Evidence={
    version="3.8.1",
    build="2026-09-26-v3.8.1-signal-extractor",
    quest={running=false,token=0,last=nil,history={},verifier={}},
    combat={running=false,token=0,last=nil,history={}},
    freezeUntil=0,
}
RAVYN.EvidenceV381=Evidence

local function log(level,msg,metadata)
    if RAVYN.Logger and RAVYN.Logger.log then RAVYN.Logger:log(level,msg,metadata or {}) end
end

local function questSnapshot()
    local players=service("Players"); local p=players and players.LocalPlayer
    local pg=p and p:FindFirstChildOfClass("PlayerGui")
    local records={}; local count=0; local truncated=false
    local function add(path,value)
        value=scalar(value); if value==nil then return end
        if count>=1800 then truncated=true; return end
        if records[path]==nil then count+=1 end
        records[path]=value
    end
    local nodes,cut=descendants(pg,2600); truncated=truncated or cut
    local inherited={}
    for _,x in ipairs(nodes) do
        local name=tostring(prop(x,"Name") or "")
        local parent=prop(x,"Parent")
        local relevant=inherited[parent] or containsWord(name,QUEST_WORDS)
        if (isA(x,"TextLabel") or isA(x,"TextButton") or isA(x,"TextBox")) then
            local txt=prop(x,"Text")
            if containsWord(txt,QUEST_WORDS) or (type(txt)=="string" and string.match(txt,"%d+%s*/%s*%d+")) then relevant=true end
        end
        inherited[x]=relevant
        if relevant then
            local path=pathOf(x)
            if isA(x,"GuiObject") then add(path..".Visible",prop(x,"Visible")) end
            if isA(x,"TextLabel") or isA(x,"TextButton") or isA(x,"TextBox") then add(path..".Text",prop(x,"Text")) end
            if isA(x,"ValueBase") then add(path..".Value",prop(x,"Value")) end
            for k,v in pairs(attrs(x)) do if containsWord(k,QUEST_WORDS) then add(path..".Attribute."..k,v) end end
        end
    end
    if p then
        for k,v in pairs(attrs(p)) do if containsWord(k,QUEST_WORDS) then add(pathOf(p)..".Attribute."..k,v) end end
    end
    return {time=os.clock(),records=records,count=count,truncated=truncated}
end

local function classifyQuestPattern(path,value)
    local low=string.lower(path)
    if type(value)=="string" then
        local a,b=string.match(value,"(%d+)%s*/%s*(%d+)")
        if a and b then return "X/Y",{current=tonumber(a),goal=tonumber(b)} end
        if containsWord(value,{"complete","completed","finished","reward"}) then return "COMPLETION_TEXT" end
        if containsWord(value,{"kill","defeat","hunt","collect"}) then return "OBJECTIVE_TEXT" end
        if containsWord(value,{"quest","mission"}) then return "QUEST_TEXT" end
    end
    if string.find(low,"visible",1,true) and type(value)=="boolean" then return "VISIBILITY" end
    if type(value)=="number" then return "NUMBER" end
    if type(value)=="boolean" then return "BOOLEAN" end
    return "VALUE"
end

local function finalizeQuestWatch(watch)
    local candidates={}
    for path,t in pairs(watch.trackers) do
        if t.changes>=3 and t.sampleCount>=4 then
            local pattern,parsed=classifyQuestPattern(path,t.last)
            local score=t.changes*3+math.min(t.distinctCount,8)*2
            if pattern=="X/Y" then score+=15 end
            if pattern=="OBJECTIVE_TEXT" or pattern=="QUEST_TEXT" then score+=8 end
            if containsWord(path,QUEST_WORDS) then score+=5 end
            table.insert(candidates,{path=path,pattern=pattern,changes=t.changes,distinctValues=t.distinctCount,sampleCount=t.sampleCount,lastValue=t.last,parsed=parsed,score=score,samples=t.samples,status="CANDIDATE_UNCONFIRMED"})
        end
    end
    table.sort(candidates,function(a,b) if a.score==b.score then return a.path<b.path end return a.score>b.score end)
    while #candidates>40 do table.remove(candidates) end
    local report={startedAt=watch.startedAt,finishedAt=os.clock(),duration=os.clock()-watch.startedAt,interval=watch.interval,samples=watch.samples,truncated=watch.truncated,candidates=candidates,shadowEvents=watch.shadowEvents}

    -- Session-level verifier: the same stable path must appear across five independent watches.
    local seen={}
    for _,c in ipairs(candidates) do
        if not seen[c.path] and (c.pattern=="X/Y" or c.pattern=="OBJECTIVE_TEXT" or c.pattern=="QUEST_TEXT") then
            seen[c.path]=true
            local v=Evidence.quest.verifier[c.path] or {sessions=0,patterns={},lastSeen=0}
            v.sessions+=1; v.patterns[c.pattern]=(v.patterns[c.pattern] or 0)+1; v.lastSeen=os.clock(); v.lastScore=c.score
            Evidence.quest.verifier[c.path]=v
            c.verificationSessions=v.sessions
            c.promotionEligible=v.sessions>=5
            c.status=c.promotionEligible and "SHADOW_VERIFIED_5_SESSIONS" or "SHADOW_OBSERVING"
        end
    end
    Evidence.quest.last=report; table.insert(Evidence.quest.history,report); while #Evidence.quest.history>10 do table.remove(Evidence.quest.history,1) end
    log("INFO","QUEST_WATCH_COMPLETE",{samples=watch.samples,candidates=#candidates,truncated=watch.truncated})
    return report
end

function RAVYN.Probes:watchQuest(duration,interval)
    if Evidence.quest.running then return result(false,"QUEST_WATCH_ALREADY_RUNNING") end
    duration=math.max(6,math.min(300,tonumber(duration) or 60))
    interval=math.max(.5,math.min(5,tonumber(interval) or 1.5))
    Evidence.quest.running=true; Evidence.quest.token+=1; local token=Evidence.quest.token
    local watch={startedAt=os.clock(),interval=interval,samples=0,trackers={},previous={},truncated=false,shadowEvents={}}
    task.spawn(function()
        local deadline=os.clock()+duration
        while Evidence.quest.running and Evidence.quest.token==token and os.clock()<deadline do
            local snap=questSnapshot(); watch.samples+=1; watch.truncated=watch.truncated or snap.truncated
            for path,value in pairs(snap.records) do
                local tr=watch.trackers[path]
                if not tr then tr={last=value,changes=0,distinct={},distinctCount=0,sampleCount=0,samples={}}; watch.trackers[path]=tr end
                tr.sampleCount+=1
                local key=type(value)..":"..tostring(value)
                if not tr.distinct[key] then tr.distinct[key]=true; tr.distinctCount+=1 end
                if tr.last~=value then
                    tr.changes+=1
                    local pattern,parsed=classifyQuestPattern(path,value)
                    if pattern=="X/Y" and parsed then
                        local action=(parsed.current>=parsed.goal) and "WOULD_CONSIDER_COMPLETE" or "WOULD_TRACK_PROGRESS"
                        local evt={time=snap.time,path=path,action=action,current=parsed.current,goal=parsed.goal}
                        table.insert(watch.shadowEvents,evt); log("INFO","QUEST_SHADOW_"..action,evt)
                    end
                    tr.last=value
                end
                if #tr.samples<12 then table.insert(tr.samples,{time=snap.time,value=value}) end
            end
            watch.previous=snap.records
            task.wait(interval)
        end
        if Evidence.quest.token==token then Evidence.quest.running=false; finalizeQuestWatch(watch) end
    end)
    return result(true,"QUEST_WATCH_STARTED",{duration=duration,interval=interval,token=token})
end

function RAVYN.Probes:stopQuestWatch()
    if not Evidence.quest.running then return result(false,"QUEST_WATCH_NOT_RUNNING") end
    Evidence.quest.running=false; Evidence.quest.token+=1
    return result(true,"QUEST_WATCH_STOPPED")
end

local function targetModel()
    local t=RAVYN.LiveAction and RAVYN.LiveAction.target
    if not t or not t.id then return nil,t end
    local raw=RAVYN.ReadAdapter and RAVYN.ReadAdapter.lastEntities and RAVYN.ReadAdapter.lastEntities[t.id]
    return raw,t
end
local function humanoidOf(model)
    if not model then return nil end
    local ok,h=pcall(function() return model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildWhichIsA("Humanoid",true) end)
    return ok and h or nil
end
local function animatorOf(h)
    if not h then return nil end
    local ok,a=pcall(function() return h:FindFirstChildOfClass("Animator") end)
    return ok and a or nil
end
local function trackKey(track)
    local anim=prop(track,"Animation")
    local id=anim and tostring(prop(anim,"AnimationId") or "") or ""
    local name=anim and tostring(prop(anim,"Name") or "") or ""
    if id=="" then id="track:"..tostring(track) end
    return id.."|"..name,id,name
end
local function combatSnapshot(watch)
    local now=os.clock(); local humResult=RAVYN.ReadAdapter:getHumanoid(); local myHum=humResult and humResult.ok and humResult.value or nil
    local myHealth=tonumber(prop(myHum,"Health")); local myMax=tonumber(prop(myHum,"MaxHealth"))
    local raw,target=targetModel(); local th=humanoidOf(raw); local targetHealth=tonumber(prop(th,"Health")); local targetMax=tonumber(prop(th,"MaxHealth"))
    local active={}; local animator=animatorOf(th)
    if animator then
        local ok,tracks=pcall(function() return animator:GetPlayingAnimationTracks() end)
        if ok then
            for _,tr in ipairs(tracks) do
                local key,id,name=trackKey(tr)
                active[key]={key=key,animationId=id,name=name,timePosition=tonumber(prop(tr,"TimePosition")) or 0,length=tonumber(prop(tr,"Length")) or 0,speed=tonumber(prop(tr,"Speed")) or tonumber(prop(tr,"PlaybackSpeed")) or 1,weight=tonumber(prop(tr,"WeightCurrent")) or 0}
            end
        end
    end
    return {time=now,myHealth=myHealth,myMax=myMax,targetId=target and target.id or nil,targetName=target and target.name or nil,targetHealth=targetHealth,targetMax=targetMax,tracks=active}
end

local function finalizeCombatWatch(watch)
    local candidates={}
    for key,t in pairs(watch.animations) do
        local med=median(t.impactLeads)
        local correlation=(t.occurrences>0) and (t.impacts/t.occurrences) or 0
        local status="EVIDENCE_INSUFFICIENT"
        if med and med<.12 then status="REJECT_LATENCY_RISK"
        elseif t.occurrences>=10 and t.impacts>=8 and correlation>=.80 and med and med>=.18 then status="TIMING_CANDIDATE_STRONG"
        elseif t.impacts>=3 and med and med>=.12 then status="TIMING_CANDIDATE_PARTIAL" end
        table.insert(candidates,{animationId=t.animationId,name=t.name,occurrences=t.occurrences,impactCorrelations=t.impacts,correlation=round(correlation,3),medianLead=med and round(med,3) or nil,minLead=t.minLead and round(t.minLead,3) or nil,maxLead=t.maxLead and round(t.maxLead,3) or nil,status=status,impactLeads=t.impactLeads})
    end
    table.sort(candidates,function(a,b)
        if a.impactCorrelations==b.impactCorrelations then return (a.medianLead or 0)>(b.medianLead or 0) end
        return a.impactCorrelations>b.impactCorrelations
    end)
    local report={startedAt=watch.startedAt,finishedAt=os.clock(),duration=os.clock()-watch.startedAt,interval=watch.interval,samples=watch.samples,damageEvents=watch.damageEvents,candidates=candidates,targetChanges=watch.targetChanges}
    Evidence.combat.last=report; table.insert(Evidence.combat.history,report); while #Evidence.combat.history>10 do table.remove(Evidence.combat.history,1) end
    log("INFO","COMBAT_WATCH_COMPLETE",{samples=watch.samples,damageEvents=watch.damageEvents,candidates=#candidates})
    return report
end

function RAVYN.Probes:watchCombat(duration,interval)
    if Evidence.combat.running then return result(false,"COMBAT_WATCH_ALREADY_RUNNING") end
    duration=math.max(5,math.min(180,tonumber(duration) or 45))
    interval=math.max(.04,math.min(.25,tonumber(interval) or .06))
    Evidence.combat.running=true; Evidence.combat.token+=1; local token=Evidence.combat.token
    local watch={startedAt=os.clock(),interval=interval,samples=0,animations={},active={},lastHealth=nil,lastTargetId=nil,damageEvents=0,targetChanges=0}
    task.spawn(function()
        local deadline=os.clock()+duration
        while Evidence.combat.running and Evidence.combat.token==token and os.clock()<deadline do
            local snap=combatSnapshot(watch); watch.samples+=1
            if snap.targetId~=watch.lastTargetId then
                if watch.lastTargetId~=nil and snap.targetId~=nil then watch.targetChanges+=1 end
                watch.active={}; watch.lastTargetId=snap.targetId
            end
            local now=snap.time
            for key,tr in pairs(snap.tracks) do
                local state=watch.animations[key]
                if not state then state={animationId=tr.animationId,name=tr.name,occurrences=0,impacts=0,impactLeads={},active=false}; watch.animations[key]=state end
                if not state.active then state.active=true; state.startedAt=now; state.occurrences+=1 end
                state.lastSeen=now; state.lastTimePosition=tr.timePosition; state.length=tr.length; state.speed=tr.speed
                watch.active[key]=state
            end
            for key,state in pairs(watch.animations) do
                if state.active and not snap.tracks[key] and now-(state.lastSeen or 0)>.12 then state.active=false end
            end
            if watch.lastHealth and snap.myHealth and snap.myHealth<watch.lastHealth-.001 then
                local damage=watch.lastHealth-snap.myHealth; watch.damageEvents+=1
                local bestKey,bestLead=nil,nil
                for key,state in pairs(watch.animations) do
                    if state.active and state.startedAt then
                        local lead=now-state.startedAt
                        if lead>=0 and lead<=3.5 and (not bestLead or lead<bestLead) then bestKey,bestLead=key,lead end
                    end
                end
                if bestKey then
                    local state=watch.animations[bestKey]; state.impacts+=1; table.insert(state.impactLeads,bestLead)
                    state.minLead=state.minLead and math.min(state.minLead,bestLead) or bestLead
                    state.maxLead=state.maxLead and math.max(state.maxLead,bestLead) or bestLead
                    log("INFO","COMBAT_IMPACT_CORRELATION",{animationId=state.animationId,name=state.name,lead=bestLead,damage=damage,target=snap.targetName})
                else
                    log("INFO","COMBAT_DAMAGE_UNCORRELATED",{damage=damage,target=snap.targetName})
                end
            end
            watch.lastHealth=snap.myHealth
            task.wait(interval)
        end
        if Evidence.combat.token==token then Evidence.combat.running=false; finalizeCombatWatch(watch) end
    end)
    return result(true,"COMBAT_WATCH_STARTED",{duration=duration,interval=interval,token=token})
end

function RAVYN.Probes:stopCombatWatch()
    if not Evidence.combat.running then return result(false,"COMBAT_WATCH_NOT_RUNNING") end
    Evidence.combat.running=false; Evidence.combat.token+=1
    return result(true,"COMBAT_WATCH_STOPPED")
end

function RAVYN:GetQuestSignalReport()
    return result(Evidence.quest.last~=nil,Evidence.quest.last and "QUEST_SIGNAL_REPORT" or "NO_QUEST_SIGNAL_REPORT",Evidence.quest.last,{running=Evidence.quest.running,verifier=Evidence.quest.verifier})
end
function RAVYN:GetCombatSignalReport()
    return result(Evidence.combat.last~=nil,Evidence.combat.last and "COMBAT_SIGNAL_REPORT" or "NO_COMBAT_SIGNAL_REPORT",Evidence.combat.last,{running=Evidence.combat.running})
end
function RAVYN:GetEvidenceStatus()
    return result(true,"EVIDENCE_STATUS",{
        questRunning=Evidence.quest.running,combatRunning=Evidence.combat.running,
        questReport=Evidence.quest.last~=nil,combatReport=Evidence.combat.last~=nil,
        questVerifier=Evidence.quest.verifier,
    })
end

function RAVYN:ReviewEvidencePromotion(bindingId,candidatePath)
    local actionBindings={QUEST_ACCEPT=true,QUEST_COMPLETE=true,PARRY=true,OPEN_CHEST=true,COLLECT_DROP=true,COLLECT_SOUL=true}
    if actionBindings[bindingId] then
        return result(false,"ACTION_SEMANTICS_UNRESOLVED",nil,{binding=bindingId,path=candidatePath,reason="Signal evidence can verify state semantics, but does not prove an action transport or arguments."})
    end
    local v=Evidence.quest.verifier[candidatePath]
    if not v or v.sessions<5 then return result(false,"EVIDENCE_GATE_NOT_MET",nil,{requiredSessions=5,observedSessions=v and v.sessions or 0}) end
    return result(true,"STATE_EVIDENCE_REVIEW_READY",{binding=bindingId,path=candidatePath,sessions=v.sessions,patterns=v.patterns})
end

function RAVYN:DiagnoseAutoPlayNow()
    local snap=(self.Features and self.Features.snapshot) or {}
    local bosses={}; local bossAlive=false
    for _,e in ipairs(snap.npcs or {}) do
        local isBoss=e.isBoss==true or e.classification=="BOSS"
        if isBoss then
            local alive=e.alive~=false and tonumber(e.health or 0)>0
            if alive then bossAlive=true end
            table.insert(bosses,{name=e.name,id=e.id,health=e.health,maxHealth=e.maxHealth,distance=e.distance,alive=alive})
        end
    end
    table.sort(bosses,function(a,b) return (tonumber(a.distance) or math.huge)<(tonumber(b.distance) or math.huge) end)
    local ap=self.AutoPlay38 or {}
    local t=self.LiveAction and self.LiveAction.target
    local diag={
        mode=self.Config.AutoPlayV38 and self.Config.AutoPlayV38.Mode or "UNKNOWN",
        autoPlay=self.Config.Intelligence and self.Config.Intelligence.AutoPlay or false,
        activity=ap.activity or "UNKNOWN",reason=ap.reason or "",
        bossAlive=bossAlive,bossCount=#bosses,bosses=bosses,
        target=t and {name=t.name,id=t.id,health=t.health,maxHealth=t.maxHealth,distance=t.distance,isBoss=t.isBoss} or nil,
        brainState=self.Brain and self.Brain.state or (self.LiveAction and self.LiveAction.positionMode) or "UNKNOWN",
    }
    log("INFO","AUTOPLAY_DIAGNOSE",diag)
    return result(true,"AUTOPLAY_DIAGNOSIS",diag)
end

function RAVYN:FreezeState(seconds)
    seconds=math.max(.5,math.min(10,tonumber(seconds) or 3))
    local wasRunning=self.FSM and self.FSM.state=="RUNNING"
    if not wasRunning then return result(false,"FREEZE_REQUIRES_RUNNING") end
    local pause=self:Pause(); if not pause.ok then return pause end
    if self.LiveAction and self.LiveAction.tween then pcall(function() self.LiveAction.tween:Cancel() end); self.LiveAction.tween=nil end
    Evidence.freezeUntil=os.clock()+seconds
    log("INFO","STATE_FROZEN",{seconds=seconds})
    task.delay(seconds,function()
        if env.RAVYN==RAVYN and RAVYN.FSM and RAVYN.FSM.state=="PAUSED" and not RAVYN._destroyed then
            RAVYN:Resume(); log("INFO","STATE_FREEZE_ENDED",{seconds=seconds})
        end
    end)
    return result(true,"STATE_FROZEN",{seconds=seconds})
end

RAVYN.SignalExtractorVersion="3.8.1"
RAVYN.Version="3.8.1-evidence"
RAVYN.Build="2026-09-26-v3.8.1-autoplay-evidence"
log("INFO","SIGNAL_EXTRACTOR_READY",{version=RAVYN.SignalExtractorVersion})
print("RAVYN v3.8.1 SIGNAL EXTRACTOR | PASSIVE QUEST + COMBAT EVIDENCE | NO ACTION BINDINGS PROMOTED")

CTX["env"]=env
CTX["result"]=result
CTX["service"]=service
CTX["prop"]=prop
CTX["pathOf"]=pathOf
CTX["isA"]=isA
CTX["attrs"]=attrs
CTX["descendants"]=descendants
CTX["scalar"]=scalar
CTX["median"]=median
CTX["round"]=round
CTX["containsWord"]=containsWord
CTX["QUEST_WORDS"]=QUEST_WORDS
CTX["Evidence"]=Evidence
CTX["log"]=log
CTX["questSnapshot"]=questSnapshot
CTX["classifyQuestPattern"]=classifyQuestPattern
CTX["finalizeQuestWatch"]=finalizeQuestWatch
CTX["targetModel"]=targetModel
CTX["humanoidOf"]=humanoidOf
CTX["animatorOf"]=animatorOf
CTX["trackKey"]=trackKey
CTX["combatSnapshot"]=combatSnapshot
CTX["finalizeCombatWatch"]=finalizeCombatWatch
return true]==========]); if not ok then return end end
do local ok=runChunk("CombatEvolutionV382.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Util=CTX["Util"]
local Logger=CTX["Logger"]
local Config=CTX["Config"]
local FSM=CTX["FSM"]
local finite=CTX["finite"]
local RAVYN=CTX["RAVYN"]
local config=CTX["config"]
local walk=CTX["walk"]
local LiveAction=CTX["LiveAction"]
local liveService=CTX["liveService"]
local liveRoot=CTX["liveRoot"]
local liveHumanoid=CTX["liveHumanoid"]
local v3=CTX["v3"]
local keyCodeFromText=CTX["keyCodeFromText"]
local rawTargetRoot=CTX["rawTargetRoot"]
local targetBasis=CTX["targetBasis"]
local groundSafe=CTX["groundSafe"]
local moveSmart=CTX["moveSmart"]
local currentSkillKeys=CTX["currentSkillKeys"]
local Brain=CTX["Brain"]
local env=CTX["env"]
local result=CTX["result"]
local prop=CTX["prop"]
local log=CTX["log"]
local animatorOf=CTX["animatorOf"]
local trackKey=CTX["trackKey"]
local physicalGate=CTX["physicalGate"]
-- v3.8.2 combat evolution: target-facing lock, cursor-independent combat input,
-- adaptive dodge learning, reactive guard, heavy finishers and skill damage learning.
RAVYN.Version="3.8.2-combat-evolution"
RAVYN.Build="2026-09-26-v3.8.2-combat-evolution"

Config.Default.CombatEvolution={
    Enabled=true,
    FaceLock=true,
    FixedMouseInput=true,
    UseHeavyAttack=false,
    HeavyCooldown=1.85,
    HeavyAfterM1=3,
    Defense={
        AdaptiveDodge=true,
        ReactiveGuard=true,
        DodgeKey="Q",
        BlockKey="Auto",
        AllowDocumentedFallback=true,
        LearnAfterImpacts=2,
        MinThreatOccurrences=6,
        MinThreatImpacts=4,
        MinThreatCorrelation=0.70,
        ThreatWindow=0.48,
        DodgeCooldown=0.58,
        GuardHold=0.26,
        SoftEvadeUnknown=true,
    },
    Learning={
        Enabled=true,
        EvaluationDelay=0.55,
        ExplorationBonus=16,
        SkillLock=0.42,
    },
}
RAVYN.Config.CombatEvolution=Util.deepMerge(Config.Default.CombatEvolution,RAVYN.Config.CombatEvolution or {})

local validateV382Base=Config.validate
function Config.validate(c)
    local ok,errors=validateV382Base(c)
    local x=c.CombatEvolution
    if type(x)~="table" or type(x.Defense)~="table" or type(x.Learning)~="table" then
        table.insert(errors,"CombatEvolution")
    else
        if type(x.Enabled)~="boolean" or type(x.FaceLock)~="boolean" or type(x.FixedMouseInput)~="boolean" or type(x.UseHeavyAttack)~="boolean" then table.insert(errors,"CombatEvolution.flags") end
        for _,k in ipairs({"HeavyCooldown","HeavyAfterM1"}) do if not finite(x[k]) or x[k]<0 then table.insert(errors,"CombatEvolution."..k) end end
        for _,k in ipairs({"LearnAfterImpacts","MinThreatOccurrences","MinThreatImpacts","MinThreatCorrelation","ThreatWindow","DodgeCooldown","GuardHold"}) do if not finite(x.Defense[k]) or x.Defense[k]<0 then table.insert(errors,"CombatEvolution.Defense."..k) end end
        for _,k in ipairs({"EvaluationDelay","ExplorationBonus","SkillLock"}) do if not finite(x.Learning[k]) or x.Learning[k]<0 then table.insert(errors,"CombatEvolution.Learning."..k) end end
        if finite(x.Defense.MinThreatCorrelation) and x.Defense.MinThreatCorrelation>1 then table.insert(errors,"CombatEvolution.Defense.MinThreatCorrelation") end
    end
    return #errors==0,errors
end

local Evolution={
    lastFaceAt=0,
    originalAutoRotate=nil,originalHumanoid=nil,
    dodgeUntil=0,dodgeSide=1,lastDodge=0,lastSoftEvade=0,
    guardDown=false,guardReleaseAt=0,guardKey=nil,guardSource="UNRESOLVED",lastGuardResolve=0,
    threatMemory={},activeTracks={},lastObservedHealth=nil,lastObservedTarget=nil,
    heavyLast=0,
    pendingSkill=nil,skillLockUntil=0,skillStats={},skillUseCount=0,
    status="READY",lastThreat=nil,
}
RAVYN.CombatEvolution=Evolution

local function evoCfg() return RAVYN.Config.CombatEvolution or Config.Default.CombatEvolution end
local function skillKeySet()
    local out={}
    for _,k in ipairs(currentSkillKeys()) do out[string.upper(tostring(k.key or ""))]=true end
    return out
end
local function isSkillConflict(key)
    if not key or key=="" then return false end
    return skillKeySet()[string.upper(key)]==true
end

local function setKeyState(text,down)
    local key=keyCodeFromText(text)
    if not key then return false,"KEY_UNMAPPED:"..tostring(text) end
    if physicalGate and not physicalGate("KEY",tostring(text)..(down and " down" or " up")) then return false,"PHYSICAL_INPUT_BLOCKED" end
    local vim=liveService("VirtualInputManager")
    if vim then
        local ok=pcall(function() vim:SendKeyEvent(down,key,false,game) end)
        if ok then return true,"VirtualInputManager" end
    end
    local env=(getgenv and getgenv()) or _G
    if down and type(env.keypress)=="function" then local ok=pcall(env.keypress,key.Value); if ok then return true,"keypress" end end
    if (not down) and type(env.keyrelease)=="function" then local ok=pcall(env.keyrelease,key.Value); if ok then return true,"keyrelease" end end
    return false,"INPUT_UNAVAILABLE"
end

local function fixedMouseButton(button)
    if physicalGate and not physicalGate("MOUSE",button==0 and "M1" or "M2") then return false,"PHYSICAL_INPUT_BLOCKED" end
    local cam=workspace.CurrentCamera
    local vp=cam and cam.ViewportSize or Vector2.new(1280,720)
    local x,y=math.floor(vp.X*.5),math.floor(vp.Y*.5)
    -- v3.9: never toggle RAVYN's ScreenGui per click (that flickered the whole menu at M1 rate).
    -- Instead click at a point the RAVYN window does not cover: centre if free, else beside the window.
    local gui=RAVYN._gui
    local win=gui and gui.Enabled and gui:FindFirstChild("Window")
    if win and win.Visible then
        local ok,p,sz=pcall(function() return win.AbsolutePosition,win.AbsoluteSize end)
        if ok and x>=p.X-8 and x<=p.X+sz.X+8 and y>=p.Y-8 and y<=p.Y+sz.Y+8 then
            local left=p.X-48; local right=p.X+sz.X+48; local top=p.Y-48; local bottom=p.Y+sz.Y+48
            if left>=40 then x=math.floor(left)
            elseif right<=vp.X-40 then x=math.floor(right)
            elseif top>=60 then y=math.floor(top)
            elseif bottom<=vp.Y-120 then y=math.floor(bottom)
            else RAVYN.CombatMobility=RAVYN.CombatMobility or {}; RAVYN.CombatMobility.m1Blocked="M1_POINT_COVERED_BY_UI" end
        end
    end
    local function restore() end
    local vim=liveService("VirtualInputManager")
    if vim then
        local ok=pcall(function()
            vim:SendMouseButtonEvent(x,y,button,true,game,0)
            task.wait(.022)
            vim:SendMouseButtonEvent(x,y,button,false,game,0)
        end)
        if ok then restore(); return true,button==0 and "VIM_FIXED_M1" or "VIM_FIXED_M2" end
    end
    local vu=liveService("VirtualUser")
    if vu then
        local ok=pcall(function()
            vu:CaptureController()
            local cf=cam and cam.CFrame or CFrame.new()
            if button==0 then vu:Button1Down(Vector2.new(x,y),cf); task.wait(.022); vu:Button1Up(Vector2.new(x,y),cf)
            else vu:Button2Down(Vector2.new(x,y),cf); task.wait(.022); vu:Button2Up(Vector2.new(x,y),cf) end
        end)
        if ok then restore(); return true,button==0 and "VU_FIXED_M1" or "VU_FIXED_M2" end
    end
    restore()
    return false,"FIXED_MOUSE_INPUT_UNAVAILABLE"
end

-- Replace the old cursor-dependent M1 dispatcher for every existing caller.
Hooks.pressMouse1=function() return fixedMouseButton(0) end
local function pressMouse2() return fixedMouseButton(1) end

local function faceCurrentTarget(target)
    local cfg=evoCfg(); if not cfg.Enabled or not cfg.FaceLock or not target then return false end
    local root=liveRoot(); local targetPos=targetBasis(target); if not root or not targetPos then return false end
    if LiveAction.tween then
        local playing=false
        pcall(function() playing=LiveAction.tween.PlaybackState==Enum.PlaybackState.Playing end)
        if playing then return false,"FACE_DEFERRED_DURING_TWEEN" end
    end
    local hum=liveHumanoid()
    if hum then
        pcall(function()
            if Evolution.originalHumanoid~=hum then
                Evolution.originalHumanoid=hum
                Evolution.originalAutoRotate=hum.AutoRotate
            elseif Evolution.originalAutoRotate==nil then
                Evolution.originalAutoRotate=hum.AutoRotate
            end
            hum.AutoRotate=false
        end)
    end
    local ok=pcall(function()
        local here=root.Position; local flat=Vector3.new(targetPos.X,here.Y,targetPos.Z)
        if (flat-here).Magnitude>.10 then
            root.AssemblyAngularVelocity=Vector3.new(0,0,0)
            root.CFrame=CFrame.lookAt(here,flat)
        end
    end)
    if ok then Evolution.lastFaceAt=os.clock() end
    return ok
end

local function restoreAutoRotate()
    local hum=Evolution.originalHumanoid or liveHumanoid()
    if hum and Evolution.originalAutoRotate~=nil then pcall(function() hum.AutoRotate=Evolution.originalAutoRotate end) end
    Evolution.originalAutoRotate=nil
    Evolution.originalHumanoid=nil
end

-- v3.8.3: config changes must not leave AutoRotate locked mid-session.
local setConfigV383Base=RAVYN.SetConfig
function RAVYN:SetConfig(path,value)
    local r=setConfigV383Base(self,path,value)
    if r and r.ok and (path=="CombatEvolution.Enabled" or path=="CombatEvolution.FaceLock") then
        local c=self.Config.CombatEvolution
        if not c or not c.Enabled or not c.FaceLock then restoreAutoRotate() end
    end
    return r
end

local function animationTracks(target)
    local raw=target and rawTargetRoot(target) and (RAVYN.ReadAdapter.lastEntities and RAVYN.ReadAdapter.lastEntities[target.id]) or nil
    if not raw then return {} end
    local hum=nil
    local okH=pcall(function() hum=RAVYN.ReadAdapter:_entityHumanoid(raw) end)
    if not okH or not hum then return {} end
    local animator=animatorOf(hum); if not animator then return {} end
    local ok,tracks=pcall(function() return animator:GetPlayingAnimationTracks() end); if not ok then return {} end
    local out={}
    for _,tr in ipairs(tracks) do
        local key,id,name=trackKey(tr)
        out[key]={track=tr,key=key,animationId=id,name=name,timePosition=tonumber(prop(tr,"TimePosition")) or 0,length=tonumber(prop(tr,"Length")) or 0,weight=tonumber(prop(tr,"WeightCurrent")) or 0,speed=tonumber(prop(tr,"Speed")) or tonumber(prop(tr,"PlaybackSpeed")) or 1}
    end
    return out
end

local function idleLike(name)
    local l=string.lower(tostring(name or ""))
    for _,s in ipairs({"idle","walk","run","jump","fall","land","breath","stand","locomotion"}) do if string.find(l,s,1,true) then return true end end
    return false
end

local function median382(list)
    if not list or #list==0 then return nil end
    local x=Util.deepCopy(list); table.sort(x); local n=#x
    if n%2==1 then return x[(n+1)/2] end
    return (x[n/2]+x[n/2+1])*.5
end

local function resolveGuardKey(now)
    local cfg=evoCfg().Defense
    -- v1.1 perf: the guard key GUI scan is bounded (≤1000 nodes) but must not repeat every 2 s in long fights.
    if now-(Evolution.lastGuardResolve or 0)<(Evolution.guardKey and 30 or 8) then return Evolution.guardKey,Evolution.guardSource end
    Evolution.lastGuardResolve=now
    local requested=tostring(cfg.BlockKey or "Auto")
    if requested~="Auto" then
        if isSkillConflict(requested) then Evolution.guardKey=nil; Evolution.guardSource="CONFLICT_WITH_SKILL:"..requested; return nil,Evolution.guardSource end
        Evolution.guardKey=requested; Evolution.guardSource="CONFIG"; return requested,"CONFIG"
    end
    local players=liveService("Players"); local p=players and players.LocalPlayer; local pg=p and p:FindFirstChildOfClass("PlayerGui")
    local candidate=nil
    if pg then
        local ok,desc=pcall(function() return pg:GetDescendants() end)
        if ok then
            local count=0
            for _,g in ipairs(desc) do
                count+=1; if count>1000 then break end
                if g:IsA("TextLabel") or g:IsA("TextButton") then
                    local txt=tostring(g.Text or ""); local low=string.lower(txt)
                    if string.find(low,"block",1,true) or string.find(low,"guard",1,true) or string.find(low,"parry",1,true) or string.find(low,"shield",1,true) then
                        local parent=g.Parent
                        if parent then
                            for _,x in ipairs(parent:GetDescendants()) do
                                if x:IsA("TextLabel") or x:IsA("TextButton") then
                                    local k=string.upper(string.gsub(tostring(x.Text or ""),"%s+",""))
                                    if string.match(k,"^[A-Z]$") and keyCodeFromText(k) and k~="Q" and not isSkillConflict(k) then candidate=k; break end
                                end
                            end
                        end
                    end
                end
                if candidate then break end
            end
        end
    end
    if candidate then Evolution.guardKey=candidate; Evolution.guardSource="GUI_DETECTED"; return candidate,Evolution.guardSource end
    if cfg.AllowDocumentedFallback and not isSkillConflict("F") then Evolution.guardKey="F"; Evolution.guardSource="DOCUMENTED_FALLBACK"; return "F",Evolution.guardSource end
    Evolution.guardKey=nil; Evolution.guardSource=isSkillConflict("F") and "F_CONFLICTS_WITH_SKILL" or "UNRESOLVED"
    return nil,Evolution.guardSource
end

-- v1.2.2: guard / dodge are requests to the CombatActionBus. The resolved guard key is an identifier for the
-- resolver and for LegacyCombatAdapter (HYBRID / LEGACY_INPUT only); nothing here presses a key.
local function releaseGuard()
    local B=RAVYN.CombatActionBus
    if B then pcall(function() B:RequestGuard(false,nil,{source="CombatEvolution"}) end) end
    Evolution.guardDown=false; Evolution.guardReleaseAt=0
end
local function holdGuard(now,duration)
    local cfg=evoCfg().Defense; if not cfg.ReactiveGuard then return false,"GUARD_DISABLED" end
    local B=RAVYN.CombatActionBus; if not B then return false,"COMBAT_BUS_UNAVAILABLE" end
    local key,source=resolveGuardKey(now)
    if key and isSkillConflict(key) then key=nil; source="GUARD_KEY_CONFLICT" end
    local r=B:RequestGuard(true,LiveAction.target,{source="CombatEvolution",key=key})
    if not r.ok then return false,r.code end
    Evolution.guardDown=true; Evolution.guardKey=key; Evolution.guardSource=tostring(source).."/"..tostring((r.value and r.value.backend) or "HELD")
    Evolution.guardReleaseAt=math.max(Evolution.guardReleaseAt or 0,now+(duration or cfg.GuardHold))
    Brain.combo.lastAction="GUARD "..tostring(key or "·")
    return true,Evolution.guardSource
end
local function directionalDodge(side)
    local B=RAVYN.CombatActionBus; if not B then return false,"COMBAT_BUS_UNAVAILABLE" end
    local r=B:RequestDash(side,LiveAction.target,{source="CombatEvolution"})
    return r.ok,r.ok and ("DASH · "..tostring(r.value and r.value.backend)) or r.code
end
-- raw VIM dodge: reached ONLY through LegacyCombatAdapter (CTX legacyDirectionalDodge)
local function legacyDirectionalDodge(side)
    local cfg=evoCfg().Defense; local q=tostring(cfg.DodgeKey or "Q")
    if isSkillConflict(q) then return false,"DODGE_KEY_CONFLICT:"..q end
    local vim=liveService("VirtualInputManager")
    if not vim then return false,"DODGE_INPUT_UNAVAILABLE" end
    local sideKey=side<0 and Enum.KeyCode.A or Enum.KeyCode.D
    local dodge=keyCodeFromText(q); if not dodge then return false,"DODGE_KEY_UNMAPPED" end
    if physicalGate and not physicalGate("KEY","DODGE "..q..(side<0 and "+A" or "+D")) then return false,"PHYSICAL_INPUT_BLOCKED" end
    local ok=pcall(function()
        vim:SendKeyEvent(true,sideKey,false,game)
        task.wait(.012)
        vim:SendKeyEvent(true,dodge,false,game)
        task.wait(.032)
        vim:SendKeyEvent(false,dodge,false,game)
        task.wait(.012)
        vim:SendKeyEvent(false,sideKey,false,game)
    end)
    return ok,ok and "DIRECTIONAL_DODGE" or "DODGE_FAILED"
end

local baseSmartDestinationV382=Hooks.smartDestination
Hooks.smartDestination=function(target,now)
    if evoCfg().Enabled and Evolution.dodgeUntil>now and target then
        local p,look,right=targetBasis(target)
        if p then
            local profile=Hooks.activeProfile(); local side=(Evolution.dodgeSide or 1)
            local dest=p+(right*(profile.side*1.45*side))-(look*(profile.rear*.30))+Vector3.new(0,1.5,0)
            local ch=RAVYN.ReadAdapter:getCharacter(); local raw=RAVYN.ReadAdapter.lastEntities and RAVYN.ReadAdapter.lastEntities[target.id]
            dest=groundSafe(dest,ch.ok and ch.value or nil,raw)
            LiveAction.positionMode=side<0 and "DODGE LEFT" or "DODGE RIGHT"
            return dest,LiveAction.positionMode
        end
    end
    return baseSmartDestinationV382(target,now)
end

local function triggerDodge(now,target,reason)
    local cfg=evoCfg().Defense; if not cfg.AdaptiveDodge then return false end
    if now-(Evolution.lastDodge or 0)<cfg.DodgeCooldown then return false end
    Evolution.lastDodge=now; Evolution.dodgeSide=-(Evolution.dodgeSide or 1); Evolution.dodgeUntil=now+math.max(.24,cfg.ThreatWindow)
    Evolution.lastThreat=reason or "THREAT"; Evolution.status="DODGING · "..Evolution.lastThreat
    local ok,src=directionalDodge(Evolution.dodgeSide)
    if target then pcall(function() moveSmart(target,false) end) end
    Brain.combo.lastAction=ok and src or LiveAction.positionMode
    return true
end

local function threatState(key,tr,now,targetId)
    local m=Evolution.threatMemory[key]
    if not m then m={animationId=tr.animationId,name=tr.name,occurrences=0,impacts=0,leads={},active=false,targetId=targetId}; Evolution.threatMemory[key]=m end
    if not m.active then m.active=true; m.startedAt=now; m.occurrences+=1 end
    m.lastSeen=now; m.lastTime=tr.timePosition; m.length=tr.length; m.weight=tr.weight
    return m
end

local function observeDefense(now,target)
    local cfg=evoCfg(); if not cfg.Enabled then return end
    if Evolution.guardDown and now>=Evolution.guardReleaseAt then releaseGuard() end
    local tracks=target and animationTracks(target) or {}
    local activeKeys={}
    for key,tr in pairs(tracks) do activeKeys[key]=true; threatState(key,tr,now,target and target.id) end
    for key,m in pairs(Evolution.threatMemory) do if m.active and not activeKeys[key] and now-(m.lastSeen or 0)>.10 then m.active=false end end

    local humNow=liveHumanoid(); local hp=humNow and tonumber(humNow.Health) or nil
    if Evolution.lastObservedHealth and hp and hp<Evolution.lastObservedHealth-.001 then
        local loss=Evolution.lastObservedHealth-hp; local best,bestLead=nil,nil
        for key,m in pairs(Evolution.threatMemory) do
            if m.active and m.startedAt and (not target or not m.targetId or m.targetId==target.id) then
                local lead=now-m.startedAt
                if lead>=.04 and lead<=3.0 and (not bestLead or lead<bestLead) then best,bestLead=m,lead end
            end
        end
        if best then
            best.impacts=(best.impacts or 0)+1; table.insert(best.leads,bestLead); while #best.leads>12 do table.remove(best.leads,1) end
            best.medianLead=median382(best.leads); best.correlation=best.impacts/math.max(1,best.occurrences)
            Evolution.lastThreat=best.animationId
        end
        -- If a hit got through, guard briefly when a safe non-skill block key is available.
        if cfg.Defense.ReactiveGuard then holdGuard(now,cfg.Defense.GuardHold) end
        Evolution.status=string.format("HIT %.0f · LEARNING",loss)
    end
    Evolution.lastObservedHealth=hp

    local imminent=nil
    for _,m in pairs(Evolution.threatMemory) do
        if m.active and m.startedAt and m.occurrences>=(cfg.Defense.MinThreatOccurrences or 6) and m.impacts>=(cfg.Defense.MinThreatImpacts or 4) and (m.correlation or 0)>=(cfg.Defense.MinThreatCorrelation or .70) and m.medianLead then
            local eta=m.medianLead-(now-m.startedAt)
            if eta>=-.03 and eta<=cfg.Defense.ThreatWindow and (not imminent or eta<imminent.eta) then imminent={m=m,eta=eta} end
        end
    end
    if imminent then
        Evolution.status=string.format("PREDICTED %.0fms · %s",math.max(0,imminent.eta)*1000,tostring(imminent.m.name~="" and imminent.m.name or imminent.m.animationId))
        if imminent.eta<=.18 and cfg.Defense.ReactiveGuard then holdGuard(now,cfg.Defense.GuardHold) end
        triggerDodge(now,target,"LEARNED ATTACK")
    elseif cfg.Defense.SoftEvadeUnknown and target then
        -- Unknown non-idle animation: reposition once, but do not spam Q until damage proves it dangerous.
        for _,tr in pairs(tracks) do
            local m=Evolution.threatMemory[tr.key]
            if m and m.occurrences<=1 and not idleLike(tr.name) and now-(m.startedAt or now)<=.11 and now-(Evolution.lastSoftEvade or 0)>.75 then
                Evolution.lastSoftEvade=now; Evolution.dodgeSide=-(Evolution.dodgeSide or 1); Evolution.dodgeUntil=now+.20
                Evolution.status="SOFT EVADE · UNKNOWN ANIMATION"
                pcall(function() moveSmart(target,false) end)
                break
            end
        end
    end
end

local function evaluateSkillLearning(now,target)
    local p=Evolution.pendingSkill; if not p then return end
    if now-p.at<(evoCfg().Learning.EvaluationDelay or .55) then return end
    local same=target and target.id==p.targetId
    if not same then Evolution.pendingSkill=nil; return end
    local hpNow=tonumber(target.health)
    local maxHp=tonumber(target.maxHealth) or p.maxHealth
    if not hpNow or not p.hpBefore or not maxHp or maxHp<=0 then Evolution.pendingSkill=nil; return end
    local drop=math.max(0,(p.hpBefore-hpNow)/maxHp*100)
    local s=Evolution.skillStats[p.key] or {samples=0,avgDamage=0,best=0}
    s.samples+=1; s.avgDamage=(s.avgDamage*.68)+(drop*.32); s.best=math.max(s.best or 0,drop); s.lastDamage=drop; Evolution.skillStats[p.key]=s
    Evolution.pendingSkill=nil
end

local function skillScore(k,now)
    local s=Evolution.skillStats[k.key] or {samples=0,avgDamage=0}
    local last=Brain.combo.lastSkillAt[k.key] or -math.huge; local profile=Hooks.activeProfile(); local cm=RAVYN.Config and RAVYN.Config.CombatMobility; local reuse=(cm and cm.Enabled and cm.AggressiveSkills) and math.max(.40,tonumber(cm.SkillInterval) or .55) or math.max(profile.skillDelay*2.0,2.0); if now-last<reuse then return -math.huge end
    local score=(s.avgDamage or 0)*12
    if (s.samples or 0)==0 then score+=evoCfg().Learning.ExplorationBonus or 16 end
    if k.key==Brain.combo.lastSkillKey then score-=10 end
    return score
end

local clientAttackV382Base=RAVYN.ClientAttack
function RAVYN:ClientAttack()
    local now=os.clock(); local cfg=evoCfg(); local target=LiveAction.target
    if cfg.Enabled and (Evolution.dodgeUntil>now or Evolution.guardDown) then return result(false,"DEFENSE_ACTIVE") end
    if cfg.Enabled and Evolution.skillLockUntil>now then return result(false,"SKILL_RECOVERY") end
    -- facing only rotates the character (no mouse, no camera, no cursor aim)
    if target then faceCurrentTarget(target) end
    -- v1.2.2: attacks are requests to the CombatActionBus (silent local action · labelled legacy · or nothing)
    local B=RAVYN.CombatActionBus; if not B then return result(false,"COMBAT_BUS_UNAVAILABLE") end
    if cfg.Enabled and cfg.UseHeavyAttack and target and now-(Evolution.heavyLast or 0)>=cfg.HeavyCooldown and Brain.combo.m1>=math.max(2,math.floor(cfg.HeavyAfterM1 or 3)) then
        local pct=(target.health and target.maxHealth and target.maxHealth>0) and (target.health/target.maxHealth*100) or 100
        local afterSkill=string.find(tostring(Brain.combo.lastAction or ""),"SKILL",1,true)~=nil
        if pct<=38 or afterSkill then
            local r=B:RequestAttack(target,{heavy=true,source="CombatEvolution"}); LiveAction.lastInputSource=(r.value and r.value.backend) or r.code
            if r.ok then Evolution.heavyLast=now; Brain.combo.m1=0; Brain.combo.lastAction="M2 HEAVY"; self.Logger:log("INFO","COMBO_HEAVY",{target=target.name,hpPct=pct}); return r end
        end
    end
    local r=B:RequestAttack(target,{source="CombatEvolution"}); LiveAction.lastInputSource=(r.value and r.value.backend) or r.code
    return r
end

local clientSkillSmartV382Base=RAVYN.ClientSkillSmart
function RAVYN:ClientSkillSmart(target,now)
    now=now or os.clock(); local cfg=evoCfg()
    if cfg.Enabled and (Evolution.dodgeUntil>now or Evolution.guardDown) then return result(false,"DEFENSE_ACTIVE") end
    if target then faceCurrentTarget(target) end
    if not cfg.Learning.Enabled then return clientSkillSmartV382Base(self,target,now) end
    local keys=currentSkillKeys(); if #keys==0 then return result(false,"NO_VISIBLE_SKILL_KEYS") end
    local profile=Hooks.activeProfile(); local targetPct=(target and target.health and target.maxHealth and target.maxHealth>0) and (target.health/target.maxHealth*100) or 100
    local cm=RAVYN.Config and RAVYN.Config.CombatMobility
    local desiredM1=(cm and cm.Enabled and cm.AggressiveSkills) and 1 or ((RAVYN.Config.SmartCombat.Profile=="Aggressive") and 1 or ((RAVYN.Config.SmartCombat.Profile=="Safe") and 3 or 2))
    if not RAVYN.Config.Combat.AutoAttack or targetPct<=24 then desiredM1=0 end
    if Brain.combo.m1<desiredM1 then return result(false,"COMBO_WAIT_M1") end
    local best,bestScore=nil,-math.huge
    for _,k in ipairs(keys) do local score=skillScore(k,now); if score>bestScore then best,bestScore=k,score end end
    if not best then return result(false,"SKILL_RECOVERY") end
    local B=RAVYN.CombatActionBus; if not B then return result(false,"COMBAT_BUS_UNAVAILABLE",best) end
    local r=B:RequestSkill(best,target,{source="CombatEvolution"}); LiveAction.lastInputSource=(r.value and r.value.backend) or r.code
    if r.ok then
        Brain.combo.lastSkillKey=best.key; Brain.combo.lastSkillAt[best.key]=now; Brain.combo.stage=(Brain.combo.stage%#keys)+1; Brain.combo.m1=0; Brain.combo.lastAction="SKILL "..best.key
        Evolution.skillUseCount+=1; Evolution.skillLockUntil=now+(cfg.Learning.SkillLock or .42)
        Evolution.pendingSkill={key=best.key,targetId=target and target.id,hpBefore=target and target.health,maxHealth=target and target.maxHealth,at=now}
        self.Logger:log("INFO","ADAPTIVE_SKILL_"..best.key,{target=target and target.name,index=best.index,score=bestScore})
        return result(true,"ADAPTIVE_SKILL_SENT",best)
    end
    return result(false,r.code,best)
end

local tickV382Base=RAVYN._tick
function RAVYN:_tick()
    tickV382Base(self)
    local target=LiveAction.target
    if self.FSM.state=="RUNNING" and evoCfg().Enabled and target then
        pcall(function() faceCurrentTarget(target) end)
    else
        restoreAutoRotate()
    end
end

-- High-frequency observer is isolated from the main automation tick.
Evolution.fastObserverToken=(Evolution.fastObserverToken or 0)+1
local fastObserverToken=Evolution.fastObserverToken
task.spawn(function()
    while not RAVYN._destroyed and Evolution.fastObserverToken==fastObserverToken do
        -- v1.2.1+: defense requests also pause while the InstaKillAdapter verifies its single finisher (the bus refuses them too)
        local ika=RAVYN.InstaKillAdapter
        if RAVYN.FSM.state=="RUNNING" and evoCfg().Enabled and not (ika and ika.locked) then
            local now=os.clock(); local target=LiveAction.target
            pcall(function() observeDefense(now,target) end)
            pcall(function() evaluateSkillLearning(now,target) end)
        end
        task.wait(.05)
    end
end)

function RAVYN:GetCombatEvolutionStatus()
    local learned=0; local threats=0
    for _,m in pairs(Evolution.threatMemory) do learned+=1; if (m.occurrences or 0)>=(evoCfg().Defense.MinThreatOccurrences or 6) and (m.impacts or 0)>=(evoCfg().Defense.MinThreatImpacts or 4) and (m.correlation or 0)>=(evoCfg().Defense.MinThreatCorrelation or .70) then threats+=1 end end
    local topSkill=nil
    for key,s in pairs(Evolution.skillStats) do if not topSkill or (s.avgDamage or 0)>(topSkill.avgDamage or 0) then topSkill={key=key,avgDamage=s.avgDamage or 0,samples=s.samples or 0,best=s.best or 0} end end
    return result(true,"COMBAT_EVOLUTION_STATUS",{
        status=Evolution.status,faceLock=evoCfg().FaceLock,dodgeActive=Evolution.dodgeUntil>os.clock(),
        guardDown=Evolution.guardDown,guardKey=Evolution.guardKey,guardSource=Evolution.guardSource,
        observedAnimations=learned,learnedThreats=threats,topSkill=topSkill,lastThreat=Evolution.lastThreat,
        comboAction=Brain.combo.lastAction,
    })
end

local stopV382Base=RAVYN.Stop
function RAVYN:Stop()
    releaseGuard(); Evolution.dodgeUntil=0; Evolution.skillLockUntil=0; Evolution.pendingSkill=nil; restoreAutoRotate()
    return stopV382Base(self)
end
local destroyV382Base=RAVYN.Destroy
function RAVYN:Destroy()
    releaseGuard(); restoreAutoRotate()
    return destroyV382Base(self)
end

print("RAVYN v3.8.2 COMBAT EVOLUTION | FACE LOCK | ADAPTIVE DODGE | REACTIVE GUARD | HEAVY + LEARNING COMBOS")
CTX["validateV382Base"]=validateV382Base
CTX["Evolution"]=Evolution
CTX["evoCfg"]=evoCfg
CTX["skillKeySet"]=skillKeySet
CTX["isSkillConflict"]=isSkillConflict
CTX["setKeyState"]=setKeyState
CTX["fixedMouseButton"]=fixedMouseButton
CTX["pressMouse2"]=pressMouse2
CTX["faceCurrentTarget"]=faceCurrentTarget
CTX["restoreAutoRotate"]=restoreAutoRotate
CTX["setConfigV383Base"]=setConfigV383Base
CTX["animationTracks"]=animationTracks
CTX["idleLike"]=idleLike
CTX["median382"]=median382
CTX["resolveGuardKey"]=resolveGuardKey
CTX["releaseGuard"]=releaseGuard
CTX["holdGuard"]=holdGuard
CTX["directionalDodge"]=directionalDodge
CTX["legacyDirectionalDodge"]=legacyDirectionalDodge
CTX["baseSmartDestinationV382"]=baseSmartDestinationV382
CTX["triggerDodge"]=triggerDodge
CTX["threatState"]=threatState
CTX["observeDefense"]=observeDefense
CTX["evaluateSkillLearning"]=evaluateSkillLearning
CTX["skillScore"]=skillScore
CTX["clientAttackV382Base"]=clientAttackV382Base
CTX["clientSkillSmartV382Base"]=clientSkillSmartV382Base
CTX["tickV382Base"]=tickV382Base
CTX["fastObserverToken"]=fastObserverToken
CTX["stopV382Base"]=stopV382Base
CTX["destroyV382Base"]=destroyV382Base
return true]==========]); if not ok then return end end
diag("RAVYN · compiling AdaptiveIntelligence",false)
do local fn,err=loadstring([==========[return function(RAVYN)
    if type(RAVYN)~="table" then error("RAVYN_BASE_MISSING") end
    if RAVYN.AdaptiveIntel and RAVYN.AdaptiveIntel.installVersion=="3.8.3.5" then return RAVYN end

    local U=RAVYN._Modules and RAVYN._Modules.Util
    local A={
        installed=true,installVersion="3.8.3.5",status="STARTING",fingerprint=nil,loadoutGeneration=0,
        profiles={},activeProfile=nil,lastLoadoutScan=0,lastQuestScan=0,quest={state="NONE",objectiveType="NONE",source="UNKNOWN"},
        questHistory={},lastQuestSignature=nil,pendingInteraction=nil,lastPromptAttempt=0,promptRejectUntil={},
        lastDialogueAttempt=0,lastQuestOverride=nil,observerToken=0,
    }
    RAVYN.AdaptiveIntel=A
    RAVYN.Version="3.8.3.5-adaptive-intelligence"
    RAVYN.Build="2026-09-27-v3.8.3.5-split-loader"

    if type(RAVYN.Config.AdaptiveIntel)~="table" then
        RAVYN.Config.AdaptiveIntel={Enabled=true,PreferActiveQuest=true,AutoQuestSources=true,QuestScanInterval=.35,LoadoutScanInterval=1,PromptRadius=18,PromptCooldown=4,VerifyWindow=2.5}
    end

    local function copy(v)
        if U and U.deepCopy then return U.deepCopy(v) end
        if type(v)~="table" then return v end
        local o={}; for k,x in pairs(v) do o[k]=copy(x) end; return o
    end
    local function res(ok,code,value,meta)
        return {ok=ok,code=code,message=code,value=value,metadata=meta or {},retryable=false}
    end
    local function low(v) return string.lower(tostring(v or "")) end
    local function clean(v) return string.gsub(string.gsub(tostring(v or ""),"^%s+",""),"%s+$","") end
    local function safe(fn,default) local ok,v=pcall(fn); if ok then return v end; return default end
    local function keyText(v)
        local s=string.upper(string.gsub(tostring(v or ""),"%s+",""))
        if s=="" then return nil end
        local ok,k=pcall(function() return Enum.KeyCode[s] end)
        return ok and k and s or nil
    end

    local function discoverSkills()
        local out={}
        local r=RAVYN.ReadAdapter and RAVYN.ReadAdapter:getSkillSlots() or nil
        if not (r and r.ok) then return out end
        for _,slot in ipairs(r.value or {}) do
            if slot.visible~=false then
                local k=nil
                for _,c in ipairs(slot.keybindCandidates or {}) do k=keyText(c.text); if k then break end end
                local name=clean(slot.skillName)
                if name=="" then
                    for _,c in ipairs(slot.skillNameCandidates or {}) do name=clean(c.text); if name~="" then break end end
                end
                local image=""
                if slot.imageIds and slot.imageIds[1] then image=tostring(slot.imageIds[1].image or "") end
                table.insert(out,{index=slot.index,key=k,name=name~="" and name or nil,path=slot.path,image=image,visible=slot.visible})
            end
        end
        table.sort(out,function(a,b) return (a.index or 0)<(b.index or 0) end)
        return out
    end

    local function fingerprint(skills)
        local p={}
        for _,s in ipairs(skills or {}) do
            table.insert(p,table.concat({tostring(s.index or "?"),tostring(s.key or "?"),tostring(s.name or "?"),tostring(s.image or "")},":"))
        end
        return table.concat(p,"|")
    end

    local function saveProfile()
        if not A.fingerprint or not A.activeProfile then return end
        A.activeProfile.lastSeen=os.clock()
        if RAVYN.CombatEvolution then A.activeProfile.skillStats=copy(RAVYN.CombatEvolution.skillStats or {}) end
        A.profiles[A.fingerprint]=A.activeProfile
    end

    local function scanLoadout(now)
        if not RAVYN.Config.AdaptiveIntel.Enabled then return end
        if now-(A.lastLoadoutScan or 0)<(RAVYN.Config.AdaptiveIntel.LoadoutScanInterval or 1) then return end
        A.lastLoadoutScan=now
        local skills=discoverSkills(); local fp=fingerprint(skills)
        if fp~="" and fp~=A.fingerprint then
            saveProfile()
            A.fingerprint=fp; A.loadoutGeneration=A.loadoutGeneration+1
            A.activeProfile=A.profiles[fp] or {fingerprint=fp,createdAt=now,skills=copy(skills),skillStats={}}
            A.activeProfile.skills=copy(skills); A.profiles[fp]=A.activeProfile
            if RAVYN.CombatEvolution then RAVYN.CombatEvolution.skillStats=copy(A.activeProfile.skillStats or {}) end
            A.status="LOADOUT DISCOVERED · "..tostring(#skills).." SKILLS"
            if RAVYN.Logger then RAVYN.Logger:log("INFO","ADAPTIVE_LOADOUT_CHANGED",{generation=A.loadoutGeneration,skills=#skills,fingerprint=fp}) end
        elseif A.activeProfile then A.activeProfile.skills=copy(skills) end
    end

    local function questTexts()
        -- v3.9.2 performance: read only the verified quest roots.
        -- Never scan the whole PlayerGui on the normal automation loop.
        local texts={}; local seen={}
        local p=game:GetService("Players").LocalPlayer; local pg=p and p:FindFirstChildOfClass("PlayerGui")
        if not pg then return texts end
        local ch=pg:FindFirstChild("ComponentsHolder")
        local lc=ch and ch:FindFirstChild("LeftCenterFramesHolder")
        local roots={lc and lc:FindFirstChild("zQuestsFrame"),ch and ch:FindFirstChild("QuestionStrip")}
        local scanned=0
        local function take(g)
            if scanned>=700 or #texts>=100 then return end
            scanned+=1
            if g:IsA("TextLabel") or g:IsA("TextButton") then
                local vis=safe(function() return g.Visible end,false)
                local txt=vis and clean(safe(function() return g.Text end,"")) or ""
                if txt~="" and not seen[txt] then seen[txt]=true; table.insert(texts,txt) end
            end
        end
        for _,root in ipairs(roots) do
            if root then
                take(root)
                local desc=safe(function() return root:GetDescendants() end,{})
                for _,g in ipairs(desc) do take(g); if scanned>=700 or #texts>=100 then break end end
            end
        end
        return texts
    end

    local function objectiveType(joined)
        if string.find(joined,"kill",1,true) or string.find(joined,"defeat",1,true) or string.find(joined,"slay",1,true) or string.find(joined,"eliminate",1,true) then return "KILL" end
        if string.find(joined,"collect",1,true) or string.find(joined,"gather",1,true) or string.find(joined,"retrieve",1,true) or string.find(joined,"obtain",1,true) then return "COLLECT" end
        if string.find(joined,"escort",1,true) or string.find(joined,"protect",1,true) then return "ESCORT" end
        if string.find(joined,"buy",1,true) or string.find(joined,"purchase",1,true) then return "PURCHASE" end
        if string.find(joined,"talk",1,true) or string.find(joined,"speak",1,true) or string.find(joined,"report",1,true) or string.find(joined,"return to",1,true) then return "TALK" end
        if string.find(joined,"interact",1,true) or string.find(joined,"activate",1,true) or string.find(joined,"use ",1,true) then return "INTERACT" end
        if string.find(joined,"go to",1,true) or string.find(joined,"reach",1,true) or string.find(joined,"travel",1,true) then return "TRAVEL" end
        return "UNKNOWN"
    end

    local function matchQuestTarget(joined)
        local best=nil; local bestScore=0
        for _,e in ipairs((RAVYN.Features and RAVYN.Features.snapshot and RAVYN.Features.snapshot.npcs) or {}) do
            if e and e.alive~=false and e.name then
                local n=low(e.name); local score=0
                if #n>=3 and string.find(joined,n,1,true) then score=120+#n end
                if score==0 then
                    for token in string.gmatch(n,"[%a%d]+") do
                        if #token>=4 and string.find(joined,token,1,true) then score=math.max(score,50+#token) end
                    end
                end
                if score>bestScore then best=e; bestScore=score end
            end
        end
        return best,bestScore
    end

    local function scanQuest(now)
        if not RAVYN.Config.AdaptiveIntel.Enabled then return A.quest end
        if now-(A.lastQuestScan or 0)<(RAVYN.Config.AdaptiveIntel.QuestScanInterval or .35) then return A.quest end
        A.lastQuestScan=now
        local texts=questTexts(); local joined=low(table.concat(texts," | "))
        local q={texts=texts,joined=joined,state="NONE",objectiveType="NONE",source="UNKNOWN",targetId=nil,targetName=nil,targetIsBoss=false,progress=nil,required=nil,confidence=0}
        if #texts>0 then
            q.state="ACTIVE"; q.objectiveType=objectiveType(joined); q.confidence=.45
            if string.find(joined,"crow",1,true) then q.source="CROW"; q.confidence=q.confidence+.15 end
            if string.find(joined,"muzan",1,true) then q.source="MUZAN"; q.confidence=q.confidence+.15 end
            local a,b=string.match(joined,"(%d+)%s*/%s*(%d+)")
            a=tonumber(a); b=tonumber(b)
            if a and b and b>0 then q.progress=a; q.required=b; q.confidence=q.confidence+.15; if a>=b then q.state="COMPLETE" end end
            if string.find(joined,"completed",1,true) or string.find(joined,"quest complete",1,true) or string.find(joined,"return to",1,true) or string.find(joined,"report back",1,true) then q.state="COMPLETE" end
            local t,score=matchQuestTarget(joined)
            if t and score>=50 then q.targetId=t.id; q.targetName=t.name; q.targetIsBoss=t.isBoss==true or t.classification=="BOSS"; q.confidence=math.min(1,q.confidence+.25) end
        end
        q.signature=table.concat({q.state,q.objectiveType,q.source,tostring(q.progress or ""),tostring(q.required or ""),tostring(q.targetId or ""),joined},"#")
        if q.signature~=A.lastQuestSignature then
            A.lastQuestSignature=q.signature
            table.insert(A.questHistory,{time=now,state=q.state,source=q.source,objectiveType=q.objectiveType,target=q.targetName,progress=q.progress,required=q.required})
            while #A.questHistory>30 do table.remove(A.questHistory,1) end
            if RAVYN.Logger then RAVYN.Logger:log("INFO","ADAPTIVE_QUEST_CHANGED",{state=q.state,source=q.source,type=q.objectiveType,target=q.targetName}) end
        end
        A.quest=q
        return q
    end

    local function rootPart()
        local r=RAVYN.ReadAdapter and RAVYN.ReadAdapter:getRootPart() or nil
        return r and r.ok and r.value or nil
    end
    local function promptPos(pr)
        local p=pr and pr.Parent
        if not p then return nil end
        if p:IsA("BasePart") then return p.Position end
        if p:IsA("Model") then
            local pp=p.PrimaryPart or p:FindFirstChild("HumanoidRootPart")
            return pp and pp.Position or nil
        end
        local bp=p:FindFirstAncestorWhichIsA("Model")
        if bp then local pp=bp.PrimaryPart or bp:FindFirstChild("HumanoidRootPart"); return pp and pp.Position or nil end
        return nil
    end
    local function promptId(pr)
        return safe(function() return pr:GetFullName() end,tostring(pr))
    end
    local function promptSource(pr)
        local s=low((safe(function() return pr.ActionText end,"") or "").." "..(safe(function() return pr.ObjectText end,"") or "").." "..safe(function() return pr.Name end,"").." "..safe(function() return pr.Parent and pr.Parent.Name end,""))
        if string.find(s,"crow",1,true) then return "CROW",s end
        if string.find(s,"muzan",1,true) then return "MUZAN",s end
        if string.find(s,"quest",1,true) or string.find(s,"mission",1,true) then return "GENERIC",s end
        return nil,s
    end
    local function findQuestPrompt(now)
        local root=rootPart(); if not root then return nil end
        local best,bestScore=nil,-math.huge
        -- v3.9: only prompts inside PromptRadius can win, so query that sphere instead of the whole workspace
        -- (previously a full workspace:GetDescendants() every tick while no quest was active).
        if now-(A.lastPromptScan or 0)<.25 then return A.lastPromptPick end
        A.lastPromptScan=now
        local list={}; local seenHolder={}
        local radius=(tonumber(RAVYN.Config.AdaptiveIntel.PromptRadius) or 18)+6
        local parts=safe(function() return workspace:GetPartBoundsInRadius(root.Position,radius) end,{})
        for i,part in ipairs(parts) do
            if i>500 then break end
            local holder=part:FindFirstAncestorWhichIsA("Model") or part
            if not seenHolder[holder] then
                seenHolder[holder]=true
                for _,d in ipairs(safe(function() return holder:GetDescendants() end,{})) do if d:IsA("ProximityPrompt") then table.insert(list,d) end end
            end
        end
        for _,x in ipairs(list) do
            if x:IsA("ProximityPrompt") and safe(function() return x.Enabled end,true) then
                local source=promptSource(x)
                if source then
                    local pos=promptPos(x)
                    if pos then
                        local d=(root.Position-pos).Magnitude
                        local max=tonumber(RAVYN.Config.AdaptiveIntel.PromptRadius) or 18
                        if d<=max then
                            local id=promptId(x); local blocked=(A.promptRejectUntil[id] or 0)>now
                            if not blocked then
                                local score=100-d
                                if A.quest and A.quest.source==source then score=score+40 end
                                if source=="CROW" or source=="MUZAN" then score=score+15 end
                                if score>bestScore then best=x; bestScore=score end
                            end
                        end
                    end
                end
            end
        end
        A.lastPromptPick=best
        return best
    end

    local function triggerPrompt(pr,now)
        if not pr or now-(A.lastPromptAttempt or 0)<(RAVYN.Config.AdaptiveIntel.PromptCooldown or 4) then return false,"PROMPT_COOLDOWN" end
        local f=(getgenv and getgenv().fireproximityprompt) or fireproximityprompt
        if type(f)~="function" then return false,"FIREPROXIMITYPROMPT_UNAVAILABLE" end
        A.lastPromptAttempt=now
        local before=A.quest and A.quest.signature or ""
        local ok,err=pcall(function() f(pr) end)
        if not ok then return false,tostring(err) end
        A.pendingInteraction={kind="PROMPT",id=promptId(pr),at=now,before=before,source=select(1,promptSource(pr))}
        A.status="QUEST SOURCE INTERACTION · VERIFYING"
        return true,"PROMPT_SENT"
    end

    local function clickDialogue(now)
        if now-(A.lastDialogueAttempt or 0)<1.5 then return false end
        local p=game:GetService("Players").LocalPlayer; local pg=p and p:FindFirstChildOfClass("PlayerGui")
        if not pg then return false end
        local vim=safe(function() return game:GetService("VirtualInputManager") end,nil); if not vim then return false end
        local best=nil
        for _,g in ipairs(safe(function() return pg:GetDescendants() end,{})) do
            if g:IsA("TextButton") and safe(function() return g.Visible end,false) and safe(function() return g.Active end,true) then
                local t=low(safe(function() return g.Text end,""))
                if t=="accept" or t=="yes" or t=="complete" or t=="claim" or t=="continue" or t=="next" then best=g; break end
            end
        end
        if not best then return false end
        A.lastDialogueAttempt=now
        local pos=best.AbsolutePosition; local size=best.AbsoluteSize; local x=math.floor(pos.X+size.X*.5); local y=math.floor(pos.Y+size.Y*.5)
        local IA=RAVYN.InputAudit; if IA and IA.note then IA.note("MOUSE","dialogue "..tostring(best.Text),"DIALOGUE") end
        local ok=pcall(function() vim:SendMouseButtonEvent(x,y,0,true,game,0); task.wait(.025); vim:SendMouseButtonEvent(x,y,0,false,game,0) end)
        if ok then A.pendingInteraction=A.pendingInteraction or {kind="DIALOGUE",id=tostring(best),at=now,before=A.quest and A.quest.signature or ""}; A.status="QUEST DIALOGUE · VERIFYING" end
        return ok
    end

    local function autoQuestSource(now)
        if not (RAVYN.Config.Intelligence and RAVYN.Config.Intelligence.AutoPlay) then return end
        if not RAVYN.Config.AdaptiveIntel.AutoQuestSources then return end
        local q=A.quest or {}
        local wants=(q.state=="NONE" or q.state=="COMPLETE")
        if A.pendingInteraction then
            local age=now-(A.pendingInteraction.at or now)
            if (q.signature or "")~=(A.pendingInteraction.before or "") then
                A.status="QUEST INTERACTION VERIFIED"; A.pendingInteraction=nil
            elseif age>.65 and age<(RAVYN.Config.AdaptiveIntel.VerifyWindow or 2.5) then
                clickDialogue(now)
            elseif age>=(RAVYN.Config.AdaptiveIntel.VerifyWindow or 2.5) then
                A.promptRejectUntil[A.pendingInteraction.id or "?"]=now+30
                A.status="QUEST INTERACTION UNVERIFIED · BACKOFF"; A.pendingInteraction=nil
            end
            return
        end
        if wants then
            local pr=findQuestPrompt(now)
            if pr then triggerPrompt(pr,now) end
        end
    end

    function RAVYN:RunAdaptiveDiscovery()
        local now=os.clock(); A.lastLoadoutScan=0; A.lastQuestScan=0; scanLoadout(now); local q=scanQuest(now)
        return res(true,"ADAPTIVE_DISCOVERY_COMPLETE",{fingerprint=A.fingerprint,skills=A.activeProfile and A.activeProfile.skills or {},quest=copy(q)})
    end
    function RAVYN:GetAdaptiveIntelStatus()
        local n=0; for _ in pairs(A.profiles) do n=n+1 end
        return res(true,"ADAPTIVE_INTEL_STATUS",{status=A.status,fingerprint=A.fingerprint,generation=A.loadoutGeneration,knownProfiles=n,skills=A.activeProfile and copy(A.activeProfile.skills) or {},quest=copy(A.quest),pendingInteraction=copy(A.pendingInteraction)})
    end
    RAVYN.GetAdaptiveIntelligenceStatus=RAVYN.GetAdaptiveIntelStatus

    function RAVYN:GetUniversalQuestStatus()
        scanQuest(os.clock())
        return res(true,"UNIVERSAL_QUEST_STATUS",copy(A.quest),{history=copy(A.questHistory)})
    end

    local baseTick=RAVYN._tick
    function RAVYN:_tick()
        local now=os.clock(); scanLoadout(now); local q=scanQuest(now); autoQuestSource(now)
        local oldMode=nil; local oldMob=nil; local oldBoss=nil; local overridden=false
        if self.Config.Intelligence.AutoPlay and self.Config.AdaptiveIntel.Enabled and self.Config.AdaptiveIntel.PreferActiveQuest and q and q.state=="ACTIVE" and q.targetName then
            oldMode=self.Config.AutoPlayV38.Mode; oldMob=self.Config.Farm.NormalMobs.TargetName; oldBoss=self.Config.Farm.Boss.TargetName
            if q.targetIsBoss then self.Config.AutoPlayV38.Mode="Bosses"; self.Config.Farm.Boss.TargetName=q.targetName
            else self.Config.AutoPlayV38.Mode="Mobs"; self.Config.Farm.NormalMobs.TargetName=q.targetName end
            overridden=true; A.lastQuestOverride=q.targetName
            if self.AutoPlay38 and self.AutoPlay38.setDecision then self.AutoPlay38:setDecision("QUEST · "..tostring(q.source),tostring(q.objectiveType).." · "..tostring(q.targetName)) end
        else A.lastQuestOverride=nil end
        local ok,err=pcall(baseTick,self)
        if overridden then self.Config.AutoPlayV38.Mode=oldMode; self.Config.Farm.NormalMobs.TargetName=oldMob; self.Config.Farm.Boss.TargetName=oldBoss end
        if not ok then if self.Logger then self.Logger:log("ERROR","ADAPTIVE_TICK_BASE_FAILED",{error=tostring(err)}) end; error(err) end
    end

    local baseStop=RAVYN.Stop
    function RAVYN:Stop()
        saveProfile(); A.pendingInteraction=nil; A.lastQuestOverride=nil
        return baseStop(self)
    end
    local baseDestroy=RAVYN.Destroy
    function RAVYN:Destroy()
        A.observerToken=A.observerToken+1; saveProfile(); A.pendingInteraction=nil
        return baseDestroy(self)
    end

    A.observerToken=A.observerToken+1
    local token=A.observerToken
    task.spawn(function()
        while not RAVYN._destroyed and A.observerToken==token do
            local now=os.clock()
            pcall(function() scanLoadout(now) end)
            pcall(function() scanQuest(now) end)
            if RAVYN.FSM and RAVYN.FSM.state=="RUNNING" then pcall(function() autoQuestSource(now) end) end
            task.wait(.20)
        end
    end)

    scanLoadout(os.clock()); scanQuest(os.clock()); A.status="READY · DYNAMIC LOADOUT + UNIVERSAL QUEST BRAIN"
    if RAVYN.Logger then RAVYN.Logger:log("INFO","ADAPTIVE_INTELLIGENCE_READY",{version=A.installVersion}) end
    print("RAVYN v3.8.3.5 ADAPTIVE INTELLIGENCE READY | SPLIT CHUNKS | UNIVERSAL QUEST BRAIN")
    return RAVYN
end]==========],"=RAVYN/AdaptiveIntelligence"); if not fn then diag("RAVYN ADAPTIVE COMPILE ERROR · "..tostring(err),true); return end; local ok,installer=pcall(fn); if not ok or type(installer)~="function" then diag("RAVYN ADAPTIVE LOAD ERROR · "..tostring(installer),true); return end; local ok2,res=pcall(installer,CTX.RAVYN); if not ok2 then diag("RAVYN ADAPTIVE INSTALL ERROR · "..tostring(res),true); return end; CTX.RAVYN=res or CTX.RAVYN; diag("RAVYN · AdaptiveIntelligence PASS",false) end
do local ok=runChunk("TravelControllerV384.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Util=CTX["Util"]
local Config=CTX["Config"]
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local Brain=CTX["Brain"]
local liveRoot=CTX["liveRoot"]
local cancelTween=CTX["cancelTween"]
local targetBasis=CTX["targetBasis"]
-- v3.8.4 TravelController: movement ownership + Smart Travel + reversible Noclip.
-- Owners: IDLE | TRAVEL | COMBAT_HOVER | DEFENSE | RECOVERY. Only one owner moves the root.

local defaults={
    Enabled=true,
    CombatRadius=16,        -- enter COMBAT_HOVER at or below
    CombatExitRadius=30,    -- leave COMBAT_HOVER above (hysteresis)
    TweenMaxDist=70,        -- legacy fallback only; v3.9.2 defaults to teleport-only
    FastTweenMaxDist=220,   -- legacy fallback only
    TweenSpeed=190,
    FastTweenSpeed=320,
    TeleportOnly=true,      -- ALL navigation uses direct teleport by default
    UnlimitedRange=true,    -- target selection ignores travel-distance caps
    TeleportCooldown=.20,   -- anti-spam only; not a distance limit
    TeleportRetargetDrift=6,
    ReturnToBossOnRespawn=true,
    RespawnReturnDelay=1.25,
    RetweenDrift=8,
    StuckTimeout=5,
    ArriveHeight=5.5,
    TravelNoclip=true,
    CombatNoclip=true,
    NoclipReleaseGrace=1.2,
}
Config.Default.TravelController=Util.deepCopy(defaults)
RAVYN.Config.TravelController=Util.deepMerge(defaults,RAVYN.Config.TravelController or {})

local validateBase=Config.validate
function Config.validate(c)
    local ok,errors=validateBase(c)
    local t=c.TravelController
    if type(t)~="table" then table.insert(errors,"TravelController")
    else
        for _,k in ipairs({"CombatRadius","CombatExitRadius","TweenMaxDist","FastTweenMaxDist","TweenSpeed","FastTweenSpeed","TeleportCooldown","TeleportRetargetDrift","RespawnReturnDelay","RetweenDrift","StuckTimeout","ArriveHeight","NoclipReleaseGrace"}) do
            if type(t[k])~="number" or t[k]~=t[k] or t[k]<0 then table.insert(errors,"TravelController."..k) end
        end
        if type(t.TravelNoclip)~="boolean" or type(t.CombatNoclip)~="boolean" or type(t.TeleportOnly)~="boolean" or type(t.UnlimitedRange)~="boolean" or type(t.ReturnToBossOnRespawn)~="boolean" then table.insert(errors,"TravelController.Flags") end
        if type(t.CombatExitRadius)=="number" and type(t.CombatRadius)=="number" and t.CombatExitRadius<t.CombatRadius then table.insert(errors,"TravelController.CombatExitRadius") end
    end
    return #errors==0,errors
end
local function tc() return RAVYN.Config.TravelController end

local MO={
    current="IDLE",previous="IDLE",since=os.clock(),reason="BOOT",transitions=0,history={},
    bypass=false,external=nil,
    travelTween=nil,travelDest=nil,travelKey=nil,travelMode="—",travelStartedAt=0,
    progressPos=nil,progressAt=0,lastTeleportAt=-math.huge,lastTeleportKey=nil,lastTeleportDest=nil,teleports=0,tweens=0,
    lastTargetSeenAt=0,liveDistance=nil,lastBoss=nil,lastRespawnReturn=nil,
}
RAVYN.MoveOwner=MO

local function setOwner(name,reason)
    if MO.current==name then MO.reason=reason or MO.reason; return end
    MO.previous=MO.current; MO.current=name; MO.since=os.clock(); MO.reason=reason or ""; MO.transitions=MO.transitions+1
    table.insert(MO.history,{at=MO.since,from=MO.previous,to=name,reason=MO.reason})
    while #MO.history>20 do table.remove(MO.history,1) end
    RAVYN.Logger:log("INFO","MOVE_OWNER "..MO.previous.." → "..name,{reason=MO.reason})
end

-- ================= Noclip (reversible) =================
local RunService=game:GetService("RunService")
local NC={active=false,char=nil,parts={},original={},stepConn=nil,addConn=nil,releaseAt=nil}
RAVYN.NoclipController=NC
local function trackPart(d)
    if d:IsA("BasePart") and not NC.parts[d] then
        NC.parts[d]=true
        if NC.original[d]==nil then NC.original[d]=d.CanCollide end
    end
end
local function noclipDisable(reason)
    if NC.stepConn then pcall(function() NC.stepConn:Disconnect() end); NC.stepConn=nil end
    if NC.addConn then pcall(function() NC.addConn:Disconnect() end); NC.addConn=nil end
    local restored=0
    for part,orig in pairs(NC.original) do
        if part and part.Parent then pcall(function() part.CanCollide=orig end); restored=restored+1 end
    end
    table.clear(NC.parts); table.clear(NC.original)
    local was=NC.active
    NC.active=false; NC.char=nil; NC.releaseAt=nil
    if was then RAVYN.Logger:log("INFO","NOCLIP_RESTORED",{parts=restored,reason=reason}) end
    return restored
end
local function noclipEnable()
    local root=liveRoot(); local char=root and root.Parent
    if not char then return false end
    NC.releaseAt=nil
    if NC.active and NC.char==char then return true end
    if NC.active then noclipDisable("CHARACTER_CHANGED") end
    NC.char=char; NC.active=true
    for _,d in ipairs(char:GetDescendants()) do trackPart(d) end
    NC.addConn=char.DescendantAdded:Connect(function(d) if NC.active then trackPart(d) end end)
    NC.stepConn=RunService.Stepped:Connect(function()
        if not NC.active then return end
        if not NC.char or not NC.char.Parent then return end
        for part in pairs(NC.parts) do
            if part.Parent then
                if part.CanCollide then part.CanCollide=false end
            else NC.parts[part]=nil; NC.original[part]=nil end
        end
    end)
    RAVYN.Logger:log("INFO","NOCLIP_ENABLED",{})
    return true
end
function RAVYN:EnableNoclip() return result(noclipEnable(),"NOCLIP_ENABLED") end
function RAVYN:DisableNoclip() local n=noclipDisable("MANUAL"); return result(true,"NOCLIP_RESTORED",{parts=n}) end

-- ================= Smart travel =================
local TweenService=game:GetService("TweenService")
local function stopTravelTween()
    if MO.travelTween then pcall(function() MO.travelTween:Cancel() end) end
    MO.travelTween=nil; MO.travelDest=nil; MO.travelKey=nil
end
local function tweenPlaying()
    return MO.travelTween~=nil and MO.travelTween.PlaybackState==Enum.PlaybackState.Playing
end
-- key identifies the travel goal (target id / source id). Teleport happens at most once per key
-- unless the cooldown elapsed AND the goal is extremely far again, or stuck recovery fires.
local function travelTo(dest,reason,key)
    local root=liveRoot(); if not root then return result(false,"NO_ROOT") end
    local c=tc(); local now=os.clock()
    local here=root.Position; local d=(here-dest).Magnitude
    MO.liveDistance=d
    if d<=2.5 then stopTravelTween(); MO.travelMode="ARRIVED"; return result(true,"ARRIVED") end
    -- v3.9.2: teleport-only navigation. Distance is intentionally unlimited.
    if c.TeleportOnly or RAVYN.Config.Movement.TravelMode=="Teleport" then
        stopTravelTween(); pcall(cancelTween)
        local drift=(MO.lastTeleportDest and (MO.lastTeleportDest-dest).Magnitude) or math.huge
        local sameGoal=MO.lastTeleportKey==key
        -- v1.1 anti-spam: a teleport to the same goal that does not hold (server correction, blocked spot)
        -- is retried at most 3× in 4 s, then that goal backs off for 2 s instead of looping.
        if MO.tpBackoffKey==key and now<(MO.tpBackoffUntil or 0) then return result(true,"TELEPORT_BACKOFF") end
        if sameGoal and drift<=(c.TeleportRetargetDrift or 6) then
            if now-MO.lastTeleportAt<(c.TeleportCooldown or .20) then return result(true,"TELEPORT_COOLDOWN") end
            if now-(MO.repeatTpAt or -math.huge)<4 then MO.repeatTp=(MO.repeatTp or 0)+1 else MO.repeatTp=1 end
            MO.repeatTpAt=now
            if MO.repeatTp>3 then
                MO.repeatTp=0; MO.tpBackoffKey=key; MO.tpBackoffUntil=now+2; MO.stuckEvents=(MO.stuckEvents or 0)+1
                RAVYN.Logger:log("WARN","TRAVEL_STUCK · teleport did not hold, backing off",{key=key})
                return result(true,"TELEPORT_BACKOFF")
            end
        else MO.repeatTp=0 end
        local look=Vector3.new(dest.X,dest.Y,dest.Z+0.01)
        local ok=pcall(function() root.CFrame=CFrame.lookAt(dest,look) end)
        if ok then
            MO.lastTeleportAt=now; MO.lastTeleportKey=key; MO.lastTeleportDest=dest; MO.teleports=MO.teleports+1; MO.travelMode="TELEPORT"
            LiveAction.lastMessage="TELEPORT → "..tostring(reason)
            return result(true,"TELEPORTED")
        end
        return result(false,"TELEPORT_FAILED")
    end
    -- legacy tween fallback (only if TeleportOnly is manually disabled in Developer mode)
    -- stuck detection while tweening
    if tweenPlaying() then
        if MO.progressPos and (here-MO.progressPos).Magnitude<1 and now-MO.progressAt>=c.StuckTimeout then
            RAVYN.Logger:log("WARN","TRAVEL_STUCK_RECOVERY",{key=key,d=d})
            stopTravelTween(); MO.lastTeleportKey=nil; MO.lastTeleportAt=-math.huge
            d=math.max(d,c.FastTweenMaxDist+1)
        elseif not MO.progressPos or (here-MO.progressPos).Magnitude>=1 then MO.progressPos=here; MO.progressAt=now end
    end
    if d>c.FastTweenMaxDist then
        local allowTeleport=(MO.lastTeleportKey~=key) or (now-MO.lastTeleportAt>=c.TeleportCooldown)
        if allowTeleport then
            stopTravelTween(); pcall(cancelTween)
            local look=Vector3.new(dest.X,dest.Y,dest.Z+0.01)
            local ok=pcall(function() root.CFrame=CFrame.lookAt(dest,look) end)
            if ok then
                MO.lastTeleportAt=now; MO.lastTeleportKey=key; MO.teleports=MO.teleports+1; MO.travelMode="TELEPORT"
                LiveAction.lastMessage="TELEPORT → "..tostring(reason)
                RAVYN.Logger:log("INFO","TRAVEL_TELEPORT",{reason=reason,d=math.floor(d)})
                return result(true,"TELEPORTED")
            end
            return result(false,"TELEPORT_FAILED")
        end
        -- already teleported for this goal: continue with fast tween instead of spamming
    end
    if tweenPlaying() and MO.travelKey==key and MO.travelDest and (MO.travelDest-dest).Magnitude<=c.RetweenDrift then
        return result(true,"TRAVEL_ACTIVE")
    end
    stopTravelTween(); pcall(cancelTween)
    local fast=d>c.TweenMaxDist
    local speed=fast and c.FastTweenSpeed or c.TweenSpeed
    local look=Vector3.new(dest.X,here.Y,dest.Z)
    local goal=(look-dest).Magnitude>.1 and CFrame.lookAt(dest,look) or CFrame.new(dest)
    local ok,tw=pcall(function() return TweenService:Create(root,TweenInfo.new(math.max(.06,d/speed),Enum.EasingStyle.Linear),{CFrame=goal}) end)
    if not ok or not tw then return result(false,"TWEEN_FAILED") end
    MO.travelTween=tw; MO.travelDest=dest; MO.travelKey=key; MO.travelStartedAt=now; MO.progressPos=here; MO.progressAt=now
    MO.travelMode=fast and "FAST TWEEN" or "TWEEN"; MO.tweens=MO.tweens+1
    tw:Play()
    LiveAction.lastMessage=MO.travelMode.." → "..tostring(reason)
    return result(true,fast and "FAST_TWEEN" or "TWEEN")
end
-- External systems (quest navigation / loot) claim TRAVEL for a short lease.
local function requestTravel(dest,reason,key,lease)
    MO.external={dest=dest,reason=reason,key=key,untilAt=os.clock()+(lease or .6)}
    if MO.current~="TRAVEL" then setOwner("TRAVEL",reason) end
    if tc().TravelNoclip then noclipEnable() end
    return travelTo(dest,reason,key)
end
local function releaseExternal() MO.external=nil end
RAVYN.TravelTo=function(_,dest,reason,key) return requestTravel(dest,reason,key) end
CTX["travelTo384"]=travelTo; CTX["requestTravel384"]=requestTravel; CTX["releaseTravel384"]=releaseExternal
CTX["setMovementOwner384"]=setOwner; CTX["noclipEnable384"]=noclipEnable; CTX["noclipDisable384"]=noclipDisable
CTX["stopTravelTween384"]=stopTravelTween

-- Manual NPC teleport keeps working through the legacy path.
local baseTeleportToNPC=RAVYN.TeleportToNPC
function RAVYN:TeleportToNPC(query)
    MO.bypass=true
    local ok,r=pcall(baseTeleportToNPC,self,query)
    MO.bypass=false
    if not ok then return result(false,"TELEPORT_ERROR",tostring(r)) end
    return r
end

-- ================= Ownership loop =================
local function defenseActive(now)
    local E=RAVYN.CombatEvolution
    return E and ((E.dodgeUntil or 0)>now or E.guardDown==true)
end
local HOVER_SET={COMBAT_HOVER=true,DEFENSE=true,RECOVERY=true}
local function ownershipStep()
    local c=tc(); local now=os.clock()
    local running=RAVYN.FSM and RAVYN.FSM.state=="RUNNING" and c.Enabled
    local root=liveRoot()
    if NC.active and root and NC.char and root.Parent~=NC.char then noclipDisable("RESPAWN") end
    if not running or not root then
        if MO.current~="IDLE" then setOwner("IDLE",running and "NO_ROOT" or "NOT_RUNNING") end
        stopTravelTween(); MO.external=nil
        if NC.active then noclipDisable("IDLE") end
        return
    end
    -- external lease (quest navigation / loot)
    if MO.external and MO.external.untilAt>now then
        if MO.current~="TRAVEL" then setOwner("TRAVEL",MO.external.reason) end
        if c.TravelNoclip then noclipEnable() end
        return
    elseif MO.external then MO.external=nil; stopTravelTween() end

    local target=LiveAction.target
    local JS=RAVYN.JobScheduler
    local allowMove=not JS or JS.allowMovement~=false
    local tp=target and targetBasis(target)
    if target and tp and allowMove then
        MO.lastTargetSeenAt=now
        if target.isBoss==true or target.classification=="BOSS" then
            MO.lastBoss={id=target.id,name=target.name,position=tp,at=now}
        end
        local d=(root.Position-tp).Magnitude; MO.liveDistance=d
        local inHover=HOVER_SET[MO.current]==true
        local wantHover=inHover and d<=c.CombatExitRadius or d<=c.CombatRadius
        -- v3.8.4.2: an emergency escape keeps RECOVERY ownership even beyond the hover exit radius
        local cmc=RAVYN.Config.CombatMobility or {}
        local emergency=Brain and Brain.forceEvade and Brain.emergency384
        if emergency and (inHover or d<=c.CombatExitRadius+(cmc.RecoveryDistance or 40)+15) then
            stopTravelTween(); setOwner("RECOVERY",string.format("escape d=%.1f",d))
            if c.CombatNoclip then noclipEnable() end
            return
        end
        -- v3.8.4.2: a just-acquired far target must stay locked briefly before a teleport-tier move
        if MO.lockId~=target.id then MO.lockId=target.id; MO.lockSince=now end
        if not c.TeleportOnly and not wantHover and d>c.FastTweenMaxDist and now-(MO.lockSince or now)<.35 then
            stopTravelTween(); return
        end
        local LC=RAVYN.LootController
        if LC and LC.active then stopTravelTween(); return end -- loot owns movement through its lease
        if wantHover then
            stopTravelTween()
            local owner="COMBAT_HOVER"
            if defenseActive(now) then owner="DEFENSE"
            elseif Brain and Brain.forceEvade and Brain.emergency384 then owner="RECOVERY" end
            setOwner(owner,string.format("d=%.1f",d))
            if c.CombatNoclip then noclipEnable() elseif NC.active then noclipDisable("COMBAT_NOCLIP_OFF") end
        else
            setOwner("TRAVEL",string.format("%s · %.0f studs",tostring(target.name),d))
            if c.TravelNoclip then noclipEnable() elseif NC.active then noclipDisable("TRAVEL_NOCLIP_OFF") end
            local h=(RAVYN.Config.CombatMobility and RAVYN.Config.CombatMobility.FlyHeight) or c.ArriveHeight
            travelTo(tp+Vector3.new(0,h,0),tostring(target.name),"target:"..tostring(target.id))
        end
        return
    end
    -- no movable target: keep collision off briefly so the next target transition is seamless
    stopTravelTween()
    if MO.current~="IDLE" then
        if now-MO.lastTargetSeenAt>=c.NoclipReleaseGrace then
            setOwner("IDLE",target and "COMBAT_ONLY" or "NO_TARGET")
            if NC.active then noclipDisable("NO_TARGET") end
        end
    elseif NC.active and now-MO.lastTargetSeenAt>=c.NoclipReleaseGrace then noclipDisable("IDLE") end
end
MO.token=(MO.token or 0)+1
local token=MO.token
task.spawn(function()
    while not RAVYN._destroyed and MO.token==token do
        local ok,err=pcall(ownershipStep)
        if not ok then RAVYN.Logger:log("ERROR","OWNERSHIP_STEP_FAILED",{error=tostring(err)}) end
        task.wait(.05)
    end
end)

local baseStop=RAVYN.Stop
function RAVYN:Stop()
    stopTravelTween(); MO.external=nil; MO.lastTeleportKey=nil
    setOwner("IDLE","STOP")
    local n=noclipDisable("STOP")
    local r=baseStop(self)
    MO.lastStopReport={noclipRestoredParts=n,owner=MO.current,at=os.clock()}
    return r
end
local baseDestroy=RAVYN.Destroy
function RAVYN:Destroy()
    MO.token=MO.token+1; stopTravelTween(); noclipDisable("DESTROY")
    return baseDestroy(self)
end
do
    local p=game:GetService("Players").LocalPlayer
    if p then
        local conn=p.CharacterAdded:Connect(function(char)
            local boss=MO.lastBoss
            stopTravelTween(); noclipDisable("RESPAWN"); MO.lastTeleportKey=nil; MO.lastTeleportDest=nil; MO.tpBackoffKey=nil; setOwner("IDLE","RESPAWN")
            if not (tc().ReturnToBossOnRespawn and boss and boss.position) then return end
            -- v1.1: the BossController owns respawn return (generation token, fresh same-boss check, no return to a dead boss)
            local BC=RAVYN.BossController
            if BC and BC.onRespawn then local okR=pcall(BC.onRespawn,char,boss); if okR then return end end
            task.spawn(function()
                local root=char and char:WaitForChild("HumanoidRootPart",12)
                if not root then return end
                task.wait(tc().RespawnReturnDelay or 1.25)
                if not RAVYN.FSM or RAVYN.FSM.state~="RUNNING" then return end
                local dest=boss.position
                -- Prefer a fresh live position if the same boss is still present.
                for _,e in ipairs((RAVYN.Features.snapshot or {}).npcs or {}) do
                    if (e.id==boss.id or (boss.name and e.name==boss.name)) and (e.isBoss==true or e.classification=="BOSS") and e.position and e.alive~=false then
                        dest=Vector3.new(e.position.x,e.position.y,e.position.z); break
                    end
                end
                local h=(RAVYN.Config.CombatMobility and RAVYN.Config.CombatMobility.FlyHeight) or tc().ArriveHeight
                MO.lastTeleportKey=nil; MO.lastTeleportDest=nil
                local r=travelTo(dest+Vector3.new(0,h,0),"RETURN TO BOSS · "..tostring(boss.name or "Boss"),"respawn-boss:"..tostring(boss.id or boss.name))
                MO.lastRespawnReturn={at=os.clock(),boss=boss.name,code=r and r.code}
            end)
        end)
        table.insert(RAVYN._connections,conn)
    end
end
function RAVYN:GetMovementStatus()
    return result(true,"MOVEMENT_STATUS",{owner=MO.current,previous=MO.previous,reason=MO.reason,travelMode=MO.travelMode,teleports=MO.teleports,tweens=MO.tweens,noclip=NC.active,distance=MO.liveDistance})
end
CTX["MO"]=MO; CTX["NC"]=NC
RAVYN.Logger:log("INFO","TRAVEL_CONTROLLER_V384_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("SchedulerV384.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local Brain=CTX["Brain"]
local distance=CTX["distance"]
local targetAllowed=CTX["targetAllowed"]
local matchesTarget=CTX["matchesTarget"]
local RADIUS_MAP=CTX["RADIUS_MAP"]
local BossAvailabilityCache=CTX["BossAvailabilityCache"]
-- v3.8.4 JobScheduler: one priority model on top of the existing chooseMode chain.
-- RAVYN.Scheduler remains the Core task scheduler; this is a separate job arbiter.
local P={EMERGENCY=140,RECOVERY=130,DEFENSE=125,ACTIVE_QUEST=115,QUEST_TURNIN=110,QUEST_ACQUIRE=105,
    QUEST_IMMEDIATE_LOOT=118,BOSS_LOOT=110,IMMEDIATE_LOOT=75,GENERAL_BOSS=80,NORMAL_FARM=70,GENERAL_LOOT=60,CASH=50,IDLE=0}
RAVYN.JobPriority=P
local JS={job="IDLE",priority=0,detail="",label="IDLE",overlay=nil,allowMovement=true,mode=nil,
    resumeJob=nil,changedAt=os.clock(),history={},bossDiag={},eligibleBossCount=0}
RAVYN.JobScheduler=JS

local function setJob(job,priority,detail,label)
    if JS.job~=job then
        table.insert(JS.history,{at=os.clock(),from=JS.job,to=job})
        while #JS.history>20 do table.remove(JS.history,1) end
        JS.changedAt=os.clock()
    end
    JS.job=job; JS.priority=priority or 0; JS.detail=detail or ""; JS.label=label or job
end

-- v3.8.4.2 BossInfo metadata (live evidence: BossInfo.Chest="World Events Chest", ChestRarity, OnlyAtNight).
-- Read generically from attributes or ValueBase descendants; cached per entity id, remembered per name.
local BossMeta={byId={},byName={}}
RAVYN.BossMeta=BossMeta
local function readBossMeta(id,name)
    if id and BossMeta.byId[id] then return BossMeta.byId[id] end
    local RA=RAVYN.ReadAdapter; local raw=RA and RA.lastEntities and id and RA.lastEntities[id]
    local meta={chest=nil,chestRarity=nil,onlyAtNight=nil,read=false}
    if raw then
        local ok,r=pcall(function() return RA:getBossInfo(raw) end)
        if ok and r and r.ok and type(r.value)=="table" then
            meta.read=true
            local a=r.value.attributes or {}
            meta.chest=a.Chest; meta.chestRarity=a.ChestRarity; meta.onlyAtNight=a.OnlyAtNight
            for path,val in pairs(r.value.values or {}) do
                local leaf=string.match(tostring(path),"([^%.]+)$")
                if leaf=="Chest" and meta.chest==nil then meta.chest=val
                elseif leaf=="ChestRarity" and meta.chestRarity==nil then meta.chestRarity=val
                elseif leaf=="OnlyAtNight" and meta.onlyAtNight==nil then meta.onlyAtNight=val end
            end
            if type(meta.chest)~="string" or meta.chest=="" then meta.chest=nil end
            meta.onlyAtNight=meta.onlyAtNight==true
        end
    end
    if id and meta.read then BossMeta.byId[id]=meta end
    if name and meta.read then
        local m=BossMeta.byName[name] or {}; m.chest=meta.chest; m.chestRarity=meta.chestRarity; m.onlyAtNight=meta.onlyAtNight
        BossMeta.byName[name]=m
    end
    return meta
end
CTX["readBossMeta"]=readBossMeta

-- Boss eligibility using the SAME rules selectBrainTarget applies (range + name filter + rules).
-- Writes into the shared BossAvailabilityCache so every consumer of hasAliveBoss() agrees.
local function refreshBossEligibility(now)
    local s=RAVYN.Features.snapshot or {}; local p=s.player or {}
    local cfg=RAVYN.Config.Farm.Boss
    -- v1.1: teleport-first. With UnlimitedRange the old 250/500-stud eligibility caps no longer apply.
    local tcx=RAVYN.Config.TravelController
    local radius=(tcx and tcx.UnlimitedRange) and math.huge or math.min(cfg.MaxDistance or math.huge,cfg.TargetRadius or math.huge,RADIUS_MAP[RAVYN.Config.Intelligence.SearchRadius] or 250)
    local diag={}; local count=0; local seenNames={}
    for _,e in ipairs(s.npcs or {}) do
        if e.isBoss==true or e.classification=="BOSS" then
            local reason="ELIGIBLE"
            local d=(p.position and e.position) and distance(p.position,e.position) or nil
            if not e.position then reason="MISSING_POSITION"
            elseif e.alive==false or not e.health or e.health<=0 then reason="DEAD"
            else
                local ok,why=targetAllowed(e,"BOSS")
                if not ok then reason=tostring(why or "RULE_FILTER")
                elseif not matchesTarget(e,cfg) then reason="TARGET_FILTER"
                elseif not d then reason="NO_PLAYER_POSITION"
                elseif d>radius then reason="OUT_OF_RANGE" end
            end
            if reason=="ELIGIBLE" then count=count+1 end
            local m=Brain.bossMemory and Brain.bossMemory[e.id]
            local meta=readBossMeta(e.id,e.name)
            local nm=BossMeta.byName[e.name]; if nm then nm.lastSeen=now; nm.streamed=true; nm.lastPos=e.position end
            table.insert(diag,{name=e.name,id=e.id,reason=reason,distance=d,health=e.health,maxHealth=e.maxHealth,recentKill=m and m.lastDownAt and now-m.lastDownAt<45 or false,
                chest=meta.chest,onlyAtNight=meta.onlyAtNight})
            seenNames[e.name]=true
        end
    end
    -- remembered bosses that are not streamed right now. Night-only bosses are never marked unavailable:
    -- no verified world-clock binding exists, so their condition is known but time is unresolved.
    for name,m in pairs(BossMeta.byName) do
        if not seenNames[name] then
            m.streamed=false
            table.insert(diag,{name=name,reason=m.onlyAtNight and "CONDITION_KNOWN_TIME_UNRESOLVED" or "NOT_STREAMED",distance=nil,chest=m.chest,onlyAtNight=m.onlyAtNight})
        end
    end
    table.sort(diag,function(a,b) return (a.distance or math.huge)<(b.distance or math.huge) end)
    JS.bossDiag=diag; JS.eligibleBossCount=count
    BossAvailabilityCache.alive=count>0; BossAvailabilityCache.checkedAt=now
end

-- v3.8.4.1: a parsed ACTIVE quest is active work even before its target is resolved.
-- Returns nil | "RESOLVED" (target known via text or learned memory) | "LEARNING".
local function questState()
    if not (RAVYN.Config.Intelligence and RAVYN.Config.Intelligence.AutoPlay) then return nil end
    -- v1.1: an objective read from LOCAL quest data (Quests.Holder.*.Tasks.*.Code) outranks GUI-text parsing.
    -- Streamed target → RESOLVED (fight it). Not streamed → LEARNING (no random farming while DirectCore travels).
    local D=RAVYN.Direct; local ob=D and D.objective
    if ob and ob.name and not ob.parked then return ob.streamed and "RESOLVED" or "LEARNING" end
    local A=RAVYN.AdaptiveIntel; local QB=RAVYN.QuestBrain; local ai=RAVYN.Config.AdaptiveIntel
    local q=A and A.quest
    if not (q and q.state=="ACTIVE" and ai and ai.Enabled and ai.PreferActiveQuest) then return nil end
    if A.lastQuestOverride~=nil or (QB and QB.learnedOverride~=nil) then return "RESOLVED" end
    return "LEARNING"
end
JS.questState=questState

local baseChooseMode=Hooks.chooseMode
Hooks.chooseMode=function()
    local now=os.clock()
    refreshBossEligibility(now)
    local QB=RAVYN.QuestBrain; local LC=RAVYN.LootController
    local qs=questState(); local qActive=qs~=nil
    -- quest-kill loot (just-killed quest target, short) outranks quest navigation and the quest itself
    local questLoot=LC and LC.active and (LC.priority or 0)>=P.QUEST_IMMEDIATE_LOOT
    -- 1) Quest navigation (travel to source / turn-in) owns the character.
    local lootPrio=(LC and LC.active and LC.priority) or 0
    local navPrio=(QB and QB.phase=="TURN_IN") and P.QUEST_TURNIN or P.QUEST_ACQUIRE
    if QB and QB.navigating and not questLoot and lootPrio<=navPrio then
        local prio=(QB.phase=="TURN_IN" and P.QUEST_TURNIN) or (QB.phase=="INVESTIGATE" and P.ACTIVE_QUEST) or P.QUEST_ACQUIRE
        setJob((QB.phase=="TURN_IN" and "QUEST_TURNIN") or (QB.phase=="INVESTIGATE" and "ACTIVE_QUEST") or "QUEST_ACQUIRE",prio,QB.state,"QUEST · "..tostring(QB.state))
        JS.allowMovement=false; JS.mode=nil; JS.overlay=nil
        return nil,false,JS.label
    end
    -- 1b) v3.8.4.3: a target death is being resolved → no new target this tick (closes the one-frame race)
    local AP=RAVYN.AutoPlay384
    if AP and AP.deathPending then
        setJob("LOOT",P.BOSS_LOOT,"DEATH_PENDING","RESOLVING TARGET DEATH")
        JS.allowMovement=false; JS.mode=nil; JS.overlay=nil
        return nil,false,JS.label
    end
    -- 2) Loot session only if it outranks the current work.
    local workPrio=qActive and P.ACTIVE_QUEST or 0
    if LC and LC.active and (LC.priority or 0)>workPrio then
        setJob("LOOT",LC.priority,LC.state,"LOOT · "..tostring(LC.state))
        JS.allowMovement=false; JS.mode=nil; JS.overlay=nil
        return nil,false,JS.label
    end
    -- 3) Existing decision chain (AutoPlayV38 → V37), with quest overrides already applied upstream.
    local mode,allow,label
    local learnByKills=RAVYN.Config.QuestBrain and RAVYN.Config.QuestBrain.LearnByNearbyKills==true
    if qs=="LEARNING" and not learnByKills then
        -- v3.8.5: no random farming while the target is unresolved; QuestBrain investigates markers / waits for evidence
        setJob("ACTIVE_QUEST",P.ACTIVE_QUEST,"QUEST_TARGET_UNRESOLVED","QUEST · "..tostring(QB and QB.state or "NEEDS EVIDENCE"))
        JS.allowMovement=false; JS.mode=nil; JS.overlay=nil
        return nil,false,JS.label
    end
    if qs=="LEARNING" then
        -- opt-in: target not resolved yet, learn from nearby kills.
        -- General bosses are excluded for this decision; restored immediately after.
        local ap=RAVYN.Config.AutoPlayV38; local savedMode=ap.Mode; ap.Mode="Mobs"
        local ok,m,a,l=pcall(baseChooseMode)
        ap.Mode=savedMode
        if not ok then error(m) end
        mode,allow,label=m,a,l
        setJob("ACTIVE_QUEST",P.ACTIVE_QUEST,"QUEST_LEARNING","QUEST LEARNING"..(label and (" · "..tostring(label)) or ""))
    else
        mode,allow,label=baseChooseMode()
    end
    if qs=="LEARNING" then -- job already set
    elseif qActive then
        -- stays ACTIVE_QUEST even between targets (mode nil), so general loot/chests cannot cut in
        setJob("ACTIVE_QUEST",P.ACTIVE_QUEST,mode=="BOSS" and "QUEST BOSS" or "QUEST KILL",label or "QUEST · WAITING FOR TARGET")
    elseif mode=="BOSS" then setJob("GENERAL_BOSS",P.GENERAL_BOSS,label,label)
    elseif mode=="MOB" then setJob("NORMAL_FARM",P.NORMAL_FARM,label,label)
    else setJob("IDLE",P.IDLE,label or "IDLE",label or "IDLE") end
    -- Overlays interrupt temporarily; the job above is kept so work resumes afterwards.
    local E=RAVYN.CombatEvolution
    if Brain.forceEvade and Brain.emergency384 then JS.overlay="EMERGENCY"
    elseif E and ((E.dodgeUntil or 0)>now or E.guardDown) then JS.overlay="DEFENSE"
    elseif Brain.forceEvade then JS.overlay="RECOVERY"
    else JS.overlay=nil end
    JS.allowMovement=allow and true or false; JS.mode=mode
    return mode,allow,label
end

function RAVYN:GetSchedulerStatus()
    return result(true,"SCHEDULER_STATUS",{job=JS.job,priority=JS.priority,overlay=JS.overlay,detail=JS.detail,eligibleBosses=JS.eligibleBossCount,bosses=JS.bossDiag})
end
CTX["JS"]=JS; CTX["JobPriority"]=P
RAVYN.Logger:log("INFO","JOB_SCHEDULER_V384_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("QuestBrainV384.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Util=CTX["Util"]
local Config=CTX["Config"]
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local liveRoot=CTX["liveRoot"]
local requestTravel=CTX["requestTravel384"]
-- v3.8.4 Universal Quest Brain: lifecycle + far-source navigation on top of AdaptiveIntel.
-- AdaptiveIntel keeps doing: quest text parsing, fireproximityprompt, dialogue click, signature verify.
-- This layer adds: source discovery at any streamed distance, source memory, travel to source,
-- accept/turn-in verification bookkeeping, target correlation learning, level-up rescans.
local defaults={
    -- v3.8.5.1: Crow/Muzan runtime semantics are UNRESOLVED (GameKnowledge). Default OFF and execution is
    -- gated by the capability provider until live evidence maps them. Legacy code is kept but cannot act.
    AutoQuest=false, AutoCrow=false, AutoMuzan=false, PresetVersion=2,
    -- v3.8.5: an unresolved quest target is investigated through evidence (quest markers), not random farming.
    -- Learning by killing nearby mobs is opt-in.
    LearnByNearbyKills=false,
    RepeatCrow=true, RepeatMuzan=true, AutoTurnIn=true,
    SourceScanInterval=8, InteractTimeout=8, SourceBackoff=30, StallSeconds=90,
    KnownSources={}, TargetMemory={},
}
Config.Default.QuestBrain=Util.deepCopy(defaults)
do
    local saved=RAVYN.Config.QuestBrain
    -- v3.8.5.1 migration: v3.8.4.1–v3.8.5 force-enabled Crow/Muzan through a preset (not a user choice).
    -- Reset them once to OFF; never migrate them to true.
    if type(saved)=="table" and (tonumber(saved.PresetVersion) or 0)<2 then saved.AutoCrow=false; saved.AutoMuzan=false; saved.PresetVersion=2 end
end
RAVYN.Config.QuestBrain=Util.deepMerge(defaults,RAVYN.Config.QuestBrain or {})
local function qc() return RAVYN.Config.QuestBrain end

local QB={
    state="IDLE",phase="IDLE",navigating=false,sources={},activeSourceId=nil,targetSourceId=nil,
    lastScanAt=-math.huge,interactStartAt=nil,preInteractSig=nil,lastLevel=nil,levelChanges=0,
    accepted=0,completed=0,failReason=nil,objective="NONE",progress=nil,required=nil,
    lastProgressAt=os.clock(),lastProgressValue=nil,stalled=false,learnedOverride=nil,
    confidence="UNKNOWN",recentTargets={},events={},lastQSig=nil,
}
RAVYN.QuestBrain=QB

local function low(v) return string.lower(tostring(v or "")) end
local function event(text,kind)
    table.insert(QB.events,{at=os.clock(),text=text,kind=kind or "info"})
    while #QB.events>30 do table.remove(QB.events,1) end
    RAVYN.Logger:log("INFO","QUEST · "..text,{})
end
local function setState(s,why) if QB.state~=s then QB.state=s end; QB.failReason=why end
-- capability gate: Crow/Muzan sources may only act when the capability provider says the system is runtime-capable
local GATE={CROW="CROW_MISSION",MUZAN="MUZAN_HUNT"}
local function capable(t)
    local key=GATE[t]; if not key then return true end
    local GK=RAVYN.GameKnowledge
    return GK~=nil and GK.capable~=nil and GK.capable(key)==true
end
QB.capable=capable
local function wantedType(t)
    local c=qc()
    if t=="CROW" then return c.AutoCrow and capable("CROW") end
    if t=="MUZAN" then return c.AutoMuzan and capable("MUZAN") end
    return c.AutoQuest
end
local function enabled()
    local c=qc()
    return RAVYN.Config.Intelligence and RAVYN.Config.Intelligence.AutoPlay and (c.AutoQuest or wantedType("CROW") or wantedType("MUZAN"))
end

-- ---------- source discovery (any distance within stream) ----------
local function promptSource(pr)
    local ok,s=pcall(function() return low(pr.ActionText.." "..pr.ObjectText.." "..pr.Name.." "..(pr.Parent and pr.Parent.Name or "")) end)
    if not ok then return nil end
    if string.find(s,"crow",1,true) then return "CROW",s end
    if string.find(s,"muzan",1,true) then return "MUZAN",s end
    if string.find(s,"quest",1,true) or string.find(s,"mission",1,true) then return "GENERIC",s end
    return nil
end
local function promptPos(pr)
    local p=pr.Parent; if not p then return nil end
    if p:IsA("BasePart") then return p.Position end
    if p:IsA("Attachment") then return p.WorldPosition end
    local m=p:IsA("Model") and p or p:FindFirstAncestorWhichIsA("Model")
    if m then local pp=m.PrimaryPart or m:FindFirstChild("HumanoidRootPart"); if pp then return pp.Position end end
    return nil
end
local function placeKey() return tostring(game.PlaceId) end
local function scanSources(now)
    if now-QB.lastScanAt<qc().SourceScanInterval then return end
    QB.lastScanAt=now
    local list={}; local ok,desc=pcall(function() return workspace:GetDescendants() end)
    if not ok then return end
    local cap=0
    for _,x in ipairs(desc) do
        cap=cap+1; if cap>12000 then break end
        if x:IsA("ProximityPrompt") then
            local t=promptSource(x)
            if t then
                local pos=promptPos(x)
                if pos then
                    local id=x:GetFullName()
                    local s=QB.sources[id] or {id=id,type=t,accepts=0,turnins=0,failures=0,backoffUntil=0}
                    s.type=t; s.prompt=x; s.position=pos; s.lastSeen=now; s.streamed=true
                    s.name=(x.ObjectText~="" and x.ObjectText) or (x.Parent and x.Parent.Name) or t
                    QB.sources[id]=s; list[id]=true
                end
            end
        end
    end
    -- invalidate / keep remembered positions for out-of-stream sources
    for id,s in pairs(QB.sources) do
        if not list[id] then s.streamed=false; s.prompt=nil end
        if now-(s.lastSeen or 0)>600 and not s.persisted then QB.sources[id]=nil end
    end
    -- persist observed positions (same place only) so far sources are reachable next session
    local known={}
    for _,s in pairs(QB.sources) do
        if s.streamed and s.position and #known<12 then
            table.insert(known,{id=s.id,type=s.type,name=s.name,place=placeKey(),x=s.position.X,y=s.position.Y,z=s.position.Z})
        end
    end
    if #known>0 then RAVYN.Config.QuestBrain.KnownSources=known end
end
local function loadPersistedSources()
    for _,k in ipairs(qc().KnownSources or {}) do
        if type(k)=="table" and k.place==placeKey() and k.id and not QB.sources[k.id] then
            QB.sources[k.id]={id=k.id,type=k.type,name=k.name,position=Vector3.new(k.x,k.y,k.z),accepts=0,turnins=0,failures=0,backoffUntil=0,lastSeen=0,streamed=false,persisted=true}
        end
    end
end
loadPersistedSources()

local function bestSource(now,preferId)
    local root=liveRoot(); if not root then return nil end
    if preferId and QB.sources[preferId] then return QB.sources[preferId] end
    local best,score=nil,-math.huge
    for _,s in pairs(QB.sources) do
        if wantedType(s.type) and (s.backoffUntil or 0)<=now and s.position then
            local d=(root.Position-s.position).Magnitude
            local sc=-d*.05+(s.accepts or 0)*8-(s.failures or 0)*12+(s.streamed and 20 or 0)
            if s.type=="CROW" or s.type=="MUZAN" then sc=sc+10 end
            if sc>score then best,score=s,sc end
        end
    end
    return best
end

-- ---------- target correlation learning ----------
local function questSig(q)
    local first=q.texts and q.texts[1] or ""
    first=string.gsub(low(first),"%d+","#")
    return tostring(q.source)..":"..tostring(q.objectiveType)..":"..string.sub(first,1,80)
end
local function learn(q,now)
    local t=LiveAction.target
    if t and t.name then QB.recentTargets[t.name]=now end
    if q.state~="ACTIVE" or not q.progress then QB.lastProgressValue=q.progress; return end
    if QB.lastProgressValue and q.progress>QB.lastProgressValue then
        QB.lastProgressAt=now; QB.stalled=false
        local sig=questSig(q); local mem=RAVYN.Config.QuestBrain.TargetMemory
        mem[sig]=mem[sig] or {}
        local newest,newestAt=nil,-math.huge
        for name,at in pairs(QB.recentTargets) do if now-at<=8 and at>newestAt then newest,newestAt=name,at end end
        if newest then
            mem[sig][newest]=(mem[sig][newest] or 0)+1
            event(string.format("Progress %d/%d · credited %s (%d)",q.progress,q.required or 0,newest,mem[sig][newest]),"success")
        else event(string.format("Progress %d/%d",q.progress,q.required or 0),"success") end
        local n=0; for _ in pairs(mem) do n=n+1 end
        if n>40 then for k in pairs(mem) do mem[k]=nil; break end end
    elseif q.progress~=QB.lastProgressValue then QB.lastProgressAt=now end
    QB.lastProgressValue=q.progress
    QB.stalled=now-QB.lastProgressAt>qc().StallSeconds
end
-- returns name, confidence for current objective
local function learnedTarget(q)
    local mem=RAVYN.Config.QuestBrain.TargetMemory[questSig(q)]
    if q.targetName then
        local hits=mem and mem[q.targetName] or 0
        return q.targetName,(hits>=1 and "VERIFIED" or "TEXT MATCH")
    end
    if not mem then return nil,"LEARNING" end
    local streamed={}
    for _,e in ipairs((RAVYN.Features.snapshot or {}).npcs or {}) do if e.alive~=false then streamed[e.name]=e end end
    local best,hits=nil,0
    for name,h in pairs(mem) do if streamed[name] and h>hits then best,hits=name,h end end
    if best and hits>=2 then return best,(hits>=3 and "HIGH" or "LEARNING"),streamed[best] end
    return nil,"LEARNING"
end
QB.learnedTarget=learnedTarget

-- ---------- level progression ----------
local function levelCheck()
    local r=RAVYN.ReadAdapter and RAVYN.ReadAdapter:getLevel()
    local lv=r and r.ok and tonumber(r.value) or nil
    if not lv then return end
    if QB.lastLevel and lv~=QB.lastLevel then
        QB.levelChanges=QB.levelChanges+1
        local A=RAVYN.AdaptiveIntel
        if A and A.promptRejectUntil then table.clear(A.promptRejectUntil) end
        for _,s in pairs(QB.sources) do s.backoffUntil=0 end
        QB.lastScanAt=-math.huge
        event("Level "..QB.lastLevel.." → "..lv.." · rescanning quest sources","info")
    end
    QB.lastLevel=lv
end

-- ---------- QuestProbe (v3.8.4.2 · evidence capture only, no semantics assumed) ----------
-- Live candidates: PlayerGui.ComponentsHolder.LeftCenterFramesHolder.zQuestsFrame, QuestionStrip,
-- "Quest Exp Factor Holder". Snapshots visible text before/after accept, kill and turn-in and diffs them.
local QP={reports={},pending={},roots={},rootsAt=-math.huge}
QB.probe=QP
local function findRoots(now)
    if now-QP.rootsAt<10 and QP.roots.zQuestsFrame and QP.roots.zQuestsFrame.Parent then return QP.roots end
    QP.rootsAt=now; QP.roots={}
    local p=game:GetService("Players").LocalPlayer; local pg=p and p:FindFirstChildOfClass("PlayerGui"); if not pg then return QP.roots end
    local a=pg:FindFirstChild("ComponentsHolder"); local b=a and a:FindFirstChild("LeftCenterFramesHolder")
    QP.roots.zQuestsFrame=b and b:FindFirstChild("zQuestsFrame") or nil
    local ok,desc=pcall(function() return pg:GetDescendants() end)
    if ok then
        for i,d in ipairs(desc) do
            if i>6000 then break end
            if d.Name=="QuestionStrip" and not QP.roots.QuestionStrip then QP.roots.QuestionStrip=d end
            if d.Name=="Quest Exp Factor Holder" and not QP.roots.QuestExpFactor then QP.roots.QuestExpFactor=d end
            if not QP.roots.zQuestsFrame and d.Name=="zQuestsFrame" then QP.roots.zQuestsFrame=d end
        end
    end
    return QP.roots
end
local function effectivelyVisible(g,root)
    local cur=g
    for _=1,12 do
        if not cur then return true end
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur==root then return true end
        cur=cur.Parent
    end
    return true
end
local function snapshot(label)
    local now=os.clock(); local roots=findRoots(now); local snap={label=label,at=now,clock=os.date("%H:%M:%S"),entries={},roots={}}
    for rname,root in pairs(roots) do
        if root and root.Parent then
            snap.roots[rname]={visible=(not root:IsA("GuiObject")) or root.Visible,attrs=root:GetAttributes()}
            local ok,desc=pcall(function() return root:GetDescendants() end)
            if ok then
                for i,d in ipairs(desc) do
                    if i>400 then break end
                    if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.Text~="" then
                        local rel=rname.."/"..string.sub(d:GetFullName(),#root:GetFullName()+2)
                        snap.entries[rel]={text=string.sub(d.Text,1,160),vis=effectivelyVisible(d,root)}
                    end
                end
            end
        end
    end
    return snap
end
local VERBS={"kill","defeat","slay","collect","gather","talk","speak","return","deliver","reach","go to","complete","claim"}
local function diff(before,after)
    local lines={}; local joined={}
    for k,v in pairs(after.entries) do
        local b=before.entries[k]
        if not b then table.insert(lines,"+ "..k.." = "..v.text..(v.vis and "" or " (hidden)"))
        elseif b.text~=v.text then table.insert(lines,"~ "..k.." : "..b.text.." → "..v.text)
        elseif b.vis~=v.vis then table.insert(lines,"~ "..k.." visible "..tostring(b.vis).." → "..tostring(v.vis)) end
        if v.vis then table.insert(joined,low(v.text)) end
    end
    for k,v in pairs(before.entries) do if not after.entries[k] then table.insert(lines,"- "..k.." = "..v.text) end end
    for rn,r in pairs(after.roots) do local b=before.roots[rn]; if b and b.visible~=r.visible then table.insert(lines,"~ root "..rn.." visible "..tostring(b.visible).." → "..tostring(r.visible)) end end
    table.sort(lines)
    local all=table.concat(joined," | ")
    local nums={}; for a,b in string.gmatch(all,"(%d+)%s*/%s*(%d+)") do table.insert(nums,a.."/"..b) end
    local verbs={}; for _,v in ipairs(VERBS) do if string.find(all,v,1,true) then table.insert(verbs,v) end end
    local npcs={}
    for _,e in ipairs((RAVYN.Features.snapshot or {}).npcs or {}) do if e.name and #e.name>=3 and string.find(all,low(e.name),1,true) then npcs[e.name]=true end end
    local npcList={}; for n in pairs(npcs) do table.insert(npcList,n) end
    return lines,nums,verbs,npcList
end
local function probeBegin(kind)
    -- v1.1 perf: automatic QuestProbe snapshots are research; they only run in Developer Mode (manual capture always works)
    if kind~="MANUAL" and not (RAVYN.Config.UI and RAVYN.Config.UI.DeveloperMode) then return end
    if QP.pending[kind] then return end
    QP.pending[kind]=snapshot("BEFORE_"..kind)
end
local function probeEnd(kind,delay)
    local before=QP.pending[kind]; if not before then return end
    QP.pending[kind]=nil
    task.delay(delay or .8,function()
        local after=snapshot("AFTER_"..kind)
        local lines,nums,verbs,npcs=diff(before,after)
        local head=string.format("[%s] %s → %s · %d changes · numbers {%s} · verbs {%s} · npc {%s}",kind,before.clock,after.clock,#lines,table.concat(nums,","),table.concat(verbs,","),table.concat(npcs,","))
        local body={head}; for i,l in ipairs(lines) do if i>25 then table.insert(body,"  … "..(#lines-25).." more"); break end; table.insert(body,"  "..l) end
        table.insert(QP.reports,{kind=kind,text=table.concat(body,"\n")})
        while #QP.reports>8 do table.remove(QP.reports,1) end
    end)
end
QB.probeBegin=probeBegin; QB.probeEnd=probeEnd
function RAVYN:CaptureQuestProbe(kind)
    kind=tostring(kind or "MANUAL")
    if QP.pending[kind] then probeEnd(kind,.1); return result(true,"QUEST_PROBE_AFTER_CAPTURED") end
    probeBegin(kind); return result(true,"QUEST_PROBE_BEFORE_CAPTURED")
end
function RAVYN:GetQuestProbeReport()
    local roots=findRoots(os.clock()); local out={"QUESTPROBE · QUEST_READ = UNRESOLVED_GAME_BINDING (evidence only)"}
    for _,n in ipairs({"zQuestsFrame","QuestionStrip","QuestExpFactor"}) do table.insert(out,n..": "..(roots[n] and roots[n]:GetFullName() or "not found")) end
    for _,r in ipairs(QP.reports) do table.insert(out,r.text) end
    if #QP.reports==0 then table.insert(out,"no before/after pairs captured yet") end
    return result(true,"QUEST_PROBE_REPORT",table.concat(out,"\n"))
end
function RAVYN:CopyQuestProbeReport()
    local f=(getgenv and getgenv().setclipboard) or G.setclipboard
    local r=self:GetQuestProbeReport(); if type(f)~="function" then return result(false,"SETCLIPBOARD_UNAVAILABLE",r.value) end
    pcall(f,r.value); return result(true,"QUEST_PROBE_COPIED")
end
-- kill hook from AutoPlayV384 (only while a quest is ACTIVE)
function QB.onKill(prev)
    local A=RAVYN.AdaptiveIntel
    if A and A.quest and A.quest.state=="ACTIVE" then probeEnd("KILL",.9); QB.killProbeArmed=false end
end

-- ---------- exclusive source (v3.8.4.1) ----------
-- AdaptiveIntel picks the best prompt near the player on its own. While QuestBrain drives, every
-- quest prompt except the chosen one is placed in AdaptiveIntel's existing promptRejectUntil table
-- for a short, refreshed window (1-1.5s). AdaptiveIntel's own 30s failure backoffs are never shortened.
local function reject(A,id,untilAt) if (A.promptRejectUntil[id] or 0)<untilAt then A.promptRejectUntil[id]=untilAt end end
local function lockSource(src,now)
    local A=RAVYN.AdaptiveIntel; if not (A and A.promptRejectUntil) then return end
    for id,_ in pairs(QB.sources) do if not src or id~=src.id then reject(A,id,now+1) end end
    local root=liveRoot()
    if root and now-(QB.lastLocalSweep or 0)>=.5 then
        -- prompts that streamed in after the last full scan
        QB.lastLocalSweep=now
        local radius=((RAVYN.Config.AdaptiveIntel and RAVYN.Config.AdaptiveIntel.PromptRadius) or 18)+8
        local ok,parts=pcall(function() return workspace:GetPartBoundsInRadius(root.Position,radius) end)
        if ok then
            local seen={}
            for i,part in ipairs(parts) do
                if i>400 then break end
                local holder=part:FindFirstAncestorWhichIsA("Model") or part
                if not seen[holder] then
                    seen[holder]=true
                    for _,d in ipairs(holder:GetDescendants()) do
                        if d:IsA("ProximityPrompt") and promptSource(d) then
                            local id=d:GetFullName()
                            if not src or id~=src.id then reject(A,id,now+1.5) end
                        end
                    end
                end
            end
        end
    end
end
-- sources of disabled types are never interacted with while the quest brain is enabled
local function blockUnwanted(now)
    local A=RAVYN.AdaptiveIntel; if not (A and A.promptRejectUntil) then return end
    for id,s in pairs(QB.sources) do if not wantedType(s.type) then reject(A,id,now+1) end end
end

-- ---------- navigation ----------
local function navigate(src,kind,q,now)
    local root=liveRoot(); if not root or not src or not src.position then return end
    local LC=RAVYN.LootController; local P=RAVYN.JobPriority
    local phasePrio=P and ((kind=="TURN_IN") and P.QUEST_TURNIN or P.QUEST_ACQUIRE) or 0
    if LC and LC.active and P and (LC.priority or 0)>phasePrio then
        -- collecting drops from the quest kill first; resume this exact source afterwards
        QB.navigating=false; QB.interactStartAt=nil; setState("WAITING FOR LOOT",nil); return
    end
    lockSource(src,now)
    local radius=(RAVYN.Config.AdaptiveIntel and RAVYN.Config.AdaptiveIntel.PromptRadius) or 18
    local d=(root.Position-src.position).Magnitude
    QB.targetSourceId=src.id; QB.navigating=true
    if d>radius-5 then
        QB.interactStartAt=nil
        setState(kind=="TURN_IN" and "RETURNING TO "..src.type or "TRAVEL TO "..src.type, src.streamed and nil or "QUEST_SOURCE_OUT_OF_STREAM")
        requestTravel(src.position+Vector3.new(0,2.5,0),"QUEST "..src.type,"source:"..src.id,.6)
        return
    end
    -- in range: AdaptiveIntel's autoQuestSource fires the prompt + dialogue; we time the verification.
    if not QB.interactStartAt then probeBegin(kind=="TURN_IN" and "TURNIN" or "ACCEPT") end
    QB.interactStartAt=QB.interactStartAt or now
    QB.preInteractSig=QB.preInteractSig or q.signature
    setState(kind=="TURN_IN" and "TURNING IN" or "ACCEPTING",nil)
    if now-QB.interactStartAt>qc().InteractTimeout then
        src.failures=(src.failures or 0)+1; src.backoffUntil=now+qc().SourceBackoff
        QB.interactStartAt=nil; QB.preInteractSig=nil; QB.navigating=false
        probeEnd(kind=="TURN_IN" and "TURNIN" or "ACCEPT",.1)
        local why=(type((getgenv and getgenv().fireproximityprompt) or fireproximityprompt)~="function") and "FIREPROXIMITYPROMPT_UNAVAILABLE" or (kind=="TURN_IN" and "QUEST_TURNIN_UNVERIFIED" or "QUEST_ACCEPT_UNVERIFIED")
        setState("INTERACTION UNVERIFIED",why); event(src.type.." interaction not verified · backoff","warn")
    end
end

-- v3.8.5.1 legacy gate: AdaptiveIntel.autoQuestSource can fire any nearby prompt it classifies as crow/muzan
-- whenever Auto Play is ON, even with every QuestBrain toggle off. While those systems are not runtime-capable,
-- keep such prompts in its existing promptRejectUntil table (refreshed 1.5s window). No legacy code is deleted.
QB.gateBlocked=0
local function gateLegacy(now)
    local A=RAVYN.AdaptiveIntel; if not (A and A.promptRejectUntil) then return end
    if capable("CROW") and capable("MUZAN") then return end
    if now-(QB.lastGateSweep or 0)<.5 then return end
    QB.lastGateSweep=now
    local root=liveRoot(); if not root then return end
    local radius=((RAVYN.Config.AdaptiveIntel and RAVYN.Config.AdaptiveIntel.PromptRadius) or 18)+10
    local ok,parts=pcall(function() return workspace:GetPartBoundsInRadius(root.Position,radius) end)
    if not ok then return end
    local seen={}; local n=0
    for i,part in ipairs(parts) do
        if i>400 then break end
        local holder=part:FindFirstAncestorWhichIsA("Model") or part
        if not seen[holder] then
            seen[holder]=true
            for _,d in ipairs(holder:GetDescendants()) do
                if d:IsA("ProximityPrompt") then
                    local t=promptSource(d)
                    if (t=="CROW" or t=="MUZAN") and not capable(t) then reject(A,d:GetFullName(),now+1.5); n=n+1 end
                end
            end
        end
    end
    QB.gateBlocked=n
end

local function tick()
    local now=os.clock()
    if RAVYN.Config.Intelligence and RAVYN.Config.Intelligence.AutoPlay and RAVYN.FSM and RAVYN.FSM.state=="RUNNING" then pcall(gateLegacy,now) end
    if not enabled() or not (RAVYN.FSM and RAVYN.FSM.state=="RUNNING") then
        QB.navigating=false; QB.learnedOverride=nil; QB.phase="IDLE"
        if QB.state~="IDLE" then setState("IDLE",nil) end
        return
    end
    local A=RAVYN.AdaptiveIntel
    if not A then setState("ADAPTIVE INTEL MISSING","ADAPTIVE_INTEL_UNAVAILABLE"); QB.navigating=false; return end
    local q=A.quest or {state="NONE"}
    levelCheck()
    -- v3.9.1: cross-check replicated player quest data with the quest GUI (read-only, ≤ every 2s).
    -- Decision logic is unchanged until the data semantics are mapped; this is evidence + display.
    if RAVYN.DataAdapters and now-(QB.dataCheckAt or 0)>2 then
        QB.dataCheckAt=now
        local okD,d=pcall(RAVYN.DataAdapters.Quests)
        if okD and d then QB.dataCheck=d; QB.questIdentity=d.questStateIdentity end
    end
    -- v3.9 perf: a full workspace source scan is only needed while acquiring/turning in (never during ACTIVE combat)
    if q.state~="ACTIVE" then scanSources(now) end
    learn(q,now)
    QB.objective=q.objectiveType or "NONE"; QB.progress=q.progress; QB.required=q.required
    -- verification of transitions driven by quest signature changes
    local sig=q.signature
    if QB.phase=="ACQUIRE" and q.state=="ACTIVE" then
        local src=QB.sources[QB.targetSourceId or ""]
        if src then src.accepts=(src.accepts or 0)+1; src.failures=0 end
        QB.activeSourceId=QB.targetSourceId; QB.accepted=QB.accepted+1
        event("Quest accepted · "..tostring(q.source).." · "..tostring(q.objectiveType),"success"); probeEnd("ACCEPT",.6)
        QB.lastProgressAt=now; QB.lastProgressValue=q.progress
    elseif QB.phase=="TURN_IN" and q.state~="COMPLETE" and sig~=QB.lastQSig then
        local src=QB.sources[QB.activeSourceId or QB.targetSourceId or ""]
        if src then src.turnins=(src.turnins or 0)+1 end
        QB.completed=QB.completed+1
        event("Quest turned in · verified","success"); probeEnd("TURNIN",.6)
        local t=src and src.type
        if (t=="CROW" and not qc().RepeatCrow) or (t=="MUZAN" and not qc().RepeatMuzan) then
            if t=="CROW" then RAVYN.Config.QuestBrain.AutoCrow=false else RAVYN.Config.QuestBrain.AutoMuzan=false end
            event(t.." repeat off · source disabled","info")
        end
        QB.activeSourceId=nil
    end
    QB.lastQSig=sig
    blockUnwanted(now)
    if A.pendingInteraction then
        local pid=A.pendingInteraction.id
        if QB.targetSourceId and pid and A.pendingInteraction.kind=="PROMPT" and pid~=QB.targetSourceId and QB.mismatchId~=pid then
            QB.mismatchId=pid; QB.failReason="QUEST_SOURCE_MISMATCH"
            event("Interacted prompt differs from chosen source","warn")
        end
        QB.navigating=true
        setState(QB.phase=="TURN_IN" and "VERIFYING TURN-IN" or "VERIFYING ACCEPT",nil)
        return
    end
    if q.state=="ACTIVE" then
        QB.phase="ACTIVE"; QB.navigating=false; QB.interactStartAt=nil; QB.preInteractSig=nil
        local ot=q.objectiveType or "UNKNOWN"
        if ot=="KILL" then
            local lt=LiveAction.target
            if lt and QB.killProbeTarget~=lt.id then QB.killProbeTarget=lt.id; QP.pending.KILL=nil; probeBegin("KILL") end
            local name,conf=learnedTarget(q)
            QB.confidence=conf
            QB.targetName=name
            if q.targetIsBoss then QB.objective="BOSS" end
            local prog=q.progress and string.format(" %d/%d",q.progress,q.required or 0) or ""
            QB.markerTarget=nil; QB.marker=nil
            if name then setState((q.targetIsBoss and "BOSS" or "KILL")..prog,QB.stalled and "QUEST_PROGRESS_STALLED" or nil)
            else
                -- evidence first: a world/Billboard marker whose text or NPC matches the quest text
                local GK=RAVYN.GameKnowledge
                local m=GK and GK.questMarker and GK.questMarker(q)
                if m then
                    QB.marker=m
                    local streamed=false
                    for _,e in ipairs((RAVYN.Features.snapshot or {}).npcs or {}) do if m.npc and e.name==m.npc and e.alive~=false then streamed=true; break end end
                    if streamed then
                        QB.markerTarget=m.npc; QB.targetName=m.npc; QB.confidence="WAYPOINT"
                        setState("KILL"..prog.." · MARKER "..m.npc,nil)
                    else
                        local root=liveRoot()
                        if root and (root.Position-m.pos).Magnitude>25 then
                            QB.navigating=true; QB.phase="INVESTIGATE"
                            requestTravel(m.pos+Vector3.new(0,4,0),"QUEST MARKER","marker:"..m.path,.6)
                            setState("INVESTIGATING MARKER"..prog,"QUEST_TARGET_UNRESOLVED")
                        else setState("AT MARKER · NO TARGET"..prog,"QUEST_TARGET_UNRESOLVED") end
                    end
                elseif qc().LearnByNearbyKills then setState("LEARNING TARGET"..prog,"QUEST_TARGET_UNRESOLVED")
                else setState("NEEDS EVIDENCE"..prog,"QUEST_TARGET_NEEDS_EVIDENCE") end
            end
        else
            QB.confidence="UNKNOWN"; QB.targetName=nil
            setState(ot.." · WAITING",(ot=="UNKNOWN") and "OBJECTIVE_UNKNOWN_OBSERVING" or ("OBJECTIVE_"..ot.."_ACTION_UNRESOLVED"))
        end
        return
    end
    if q.state=="COMPLETE" then
        if not qc().AutoTurnIn then QB.phase="COMPLETE"; QB.navigating=false; setState("COMPLETE · TURN-IN OFF",nil); return end
        QB.phase="TURN_IN"
        local src=bestSource(now,QB.activeSourceId)
        if not src then QB.navigating=false; setState("TURN-IN SOURCE UNKNOWN","QUEST_SOURCE_NOT_FOUND"); return end
        navigate(src,"TURN_IN",q,now)
        return
    end
    -- NONE: acquire a new quest (farming continues if no source is known — pre-farm during cooldown)
    QB.phase="ACQUIRE"
    local src=bestSource(now,nil)
    if not src then QB.navigating=false; setState("SEARCHING SOURCE","QUEST_SOURCE_NOT_FOUND"); return end
    navigate(src,"ACQUIRE",q,now)
end

function RAVYN:SetQuestOption(key,value)
    local allowed={AutoQuest=true,AutoCrow=true,AutoMuzan=true,RepeatCrow=true,RepeatMuzan=true,AutoTurnIn=true,LearnByNearbyKills=true}
    if not allowed[key] or type(value)~="boolean" then return result(false,"INVALID_QUEST_OPTION") end
    if value and (key=="AutoCrow" or key=="RepeatCrow") and not capable("CROW") then return result(false,"RESEARCH_REQUIRED",{system="CROW_MISSION"}) end
    if value and (key=="AutoMuzan" or key=="RepeatMuzan") and not capable("MUZAN") then return result(false,"RESEARCH_REQUIRED",{system="MUZAN_HUNT"}) end
    local r=self:SetConfig("QuestBrain."..key,value)
    if r.ok and value and (key=="AutoCrow" or key=="AutoMuzan" or key=="AutoQuest") then QB.lastScanAt=-math.huge end
    return r
end
function RAVYN:GetQuestBrainStatus()
    local A=self.AdaptiveIntel; local q=A and A.quest or {}
    local src=QB.sources[QB.activeSourceId or QB.targetSourceId or ""]
    local n=0; for _ in pairs(QB.sources) do n=n+1 end
    return result(true,"QUEST_BRAIN_STATUS",{state=QB.state,phase=QB.phase,navigating=QB.navigating,source=src and src.type or q.source,
        sourceName=src and src.name,objective=QB.objective,target=QB.targetName,confidence=QB.confidence,progress=QB.progress,required=QB.required,
        stalled=QB.stalled,failReason=QB.failReason,accepted=QB.accepted,completed=QB.completed,knownSources=n,level=QB.lastLevel})
end

QB.token=(QB.token or 0)+1
local token=QB.token
task.spawn(function()
    while not RAVYN._destroyed and QB.token==token do
        local ok,err=pcall(tick)
        if not ok then QB.failReason="QB_TICK_ERROR"; RAVYN.Logger:log("ERROR","QUEST_BRAIN_TICK",{error=tostring(err)}) end
        task.wait(.25)
    end
end)
local baseStop=RAVYN.Stop
function RAVYN:Stop()
    QB.navigating=false; QB.learnedOverride=nil; QB.interactStartAt=nil; QB.phase="IDLE"; setState("IDLE",nil)
    return baseStop(self)
end
local baseDestroy=RAVYN.Destroy
function RAVYN:Destroy() QB.token=QB.token+1; return baseDestroy(self) end
CTX["QB"]=QB
RAVYN.Logger:log("INFO","QUEST_BRAIN_V384_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("LootControllerV384.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Util=CTX["Util"]
local Config=CTX["Config"]
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local liveRoot=CTX["liveRoot"]
local requestTravel=CTX["requestTravel384"]
local P=CTX["JobPriority"]
-- v3.8.4.2 LootController
-- Kill/boss: DEATH → (BossInfo.Chest identity search) → drops by SPAWN-TIMING evidence → collect all → verify.
-- A drop = object that appeared near the kill/chest after the pre-kill/pre-open baseline AND exposes a real
-- interaction affordance (ProximityPrompt / ClickDetector / TouchTransmitter). No remotes, ever.
local defaults={
    AutoLootAfterKill=true, AutoLootChests=true, CollectNearbyLoot=false,
    LootSpawnWait=0.35, LootRescanInterval=0.15, LootQuietWindow=1.0, LootSessionTimeout=10,
    KillLootRadius=26, ChestSearchRadius=80, ImmediateChestRadius=40, ChestScanInterval=3,
    QuestLootRadius=18, QuestLootTimeout=5, MaxPreemptedSeconds=30,
    ChestIdentityRadius=140, ChestSpawnWait=10, ChestDropRadius=22, BossLootTimeout=25,
}
Config.Default.Loot384=Util.deepCopy(defaults)
RAVYN.Config.Loot384=Util.deepMerge(defaults,RAVYN.Config.Loot384 or {})
local function lc() return RAVYN.Config.Loot384 end

local LC={active=false,state="IDLE",kind=nil,priority=0,sessionId=0,detected=0,attempted=0,collected=0,unverified=0,remaining=0,
    lastResult="—",failReason=nil,sessions=0,totalCollected=0,events={},chestBackoff={},lastChestScanAt=0,
    bossName=nil,expectedChest=nil,chestState="—",chestPath=nil,chestInteraction=nil,chestDistance=nil,probe=nil}
RAVYN.LootController=LC
local S=nil -- the one active session (single LootSession invariant)

local function event(text,kind)
    table.insert(LC.events,{at=os.clock(),text=text,kind=kind or "info"})
    while #LC.events>30 do table.remove(LC.events,1) end
    RAVYN.Logger:log("INFO","LOOT · "..text,{})
end
local function exec(name) local f=(getgenv and getgenv()[name]) or (G[name]); return type(f)=="function" and f or nil end
local function low(v) return string.lower(tostring(v or "")) end
local QUEST_WORDS={"crow","muzan","quest","mission","talk","speak"}
local CHEST_WORDS={"chest","sealed","coffer","treasure"} -- bare "open" is not chest evidence
local DROP_WORDS={"pick","collect","loot","take","grab","claim","drop","soul","item","reward","orb","material"}
local function hasAny(s,words) for _,w in ipairs(words) do if string.find(s,w,1,true) then return true end end; return false end
local function promptText(pr)
    local ok,s=pcall(function() return low(pr.ActionText.." "..pr.ObjectText.." "..pr.Name.." "..(pr.Parent and pr.Parent.Name or "")) end)
    return ok and s or ""
end
local function isPlayerOrNpc(inst)
    local m=inst:IsA("Model") and inst or inst:FindFirstAncestorWhichIsA("Model")
    return m~=nil and m:FindFirstChildOfClass("Humanoid")~=nil
end
local function posOf(inst)
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Attachment") then return inst.WorldPosition end
    if inst:IsA("Model") then local ok,cf=pcall(function() return inst:GetPivot() end); if ok then return cf.Position end end
    local bp=inst:FindFirstAncestorWhichIsA("BasePart"); return bp and bp.Position or nil
end
-- holder = smallest sensible object a part belongs to (large world models fall back to the part)
local function holderOf(part)
    local m=part:FindFirstAncestorWhichIsA("Model")
    if m and m~=workspace then
        local ok,size=pcall(function() return m:GetExtentsSize() end)
        if ok and size.Magnitude<=60 then return m end
    end
    return part
end
-- interaction affordance of a holder (bounded)
local function affordance(holder)
    local list={holder}
    local ok,desc=pcall(function() return holder:GetDescendants() end)
    if ok then for i,d in ipairs(desc) do if i>80 then break end; table.insert(list,d) end end
    local touch=nil
    for _,d in ipairs(list) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            local t=promptText(d); if hasAny(t,QUEST_WORDS) then return nil end
            return {kind="PROMPT",prompt=d,text=t}
        elseif d:IsA("ClickDetector") then return {kind="CLICK",click=d}
        elseif d.ClassName=="TouchTransmitter" and d.Parent and d.Parent:IsA("BasePart") then touch=touch or {kind="TOUCH",part=d.Parent,transmitter=d} end
    end
    return touch
end
local function partsNear(center,radius)
    local params=OverlapParams.new(); local root=liveRoot()
    if root and root.Parent then params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={root.Parent} end
    local ok,parts=pcall(function() return workspace:GetPartBoundsInRadius(center,radius,params) end)
    return ok and parts or {}
end
-- baseline = set of holders present now (instance keys). Used pre-kill (AutoPlayV384) and pre-open.
local function baselineSet(center,radius)
    local set={}
    for i,p in ipairs(partsNear(center,radius)) do if i>900 then break end; set[holderOf(p)]=true end
    return set
end
LC.baselineSet=baselineSet
-- kept for compatibility with older callers
function LC.scanPrompts(center,radius)
    local out={}
    for h in pairs(baselineSet(center,radius)) do out[#out+1]={id=h,holder=h} end
    return out
end
local function newCandidates(zone,chestHolder)
    local out={}; local seen={}
    for i,p in ipairs(partsNear(zone.center,zone.radius)) do
        if i>900 then break end
        local h=holderOf(p)
        if not seen[h] and h~=chestHolder and not (chestHolder and h:IsDescendantOf(chestHolder)) then
            seen[h]=true
            local isNew=not zone.baseline[h]
            if (isNew or zone.nearby) and not isPlayerOrNpc(h) then
                local a=affordance(h)
                if a and (isNew or (a.kind=="PROMPT" and hasAny(a.text,DROP_WORDS))) then
                    table.insert(out,{holder=h,aff=a,pos=posOf(a.prompt or a.click or a.part or h) or posOf(h)})
                end
            end
        end
    end
    return out
end
local function affGone(it)
    local h=it.holder; if not h or not h.Parent then return true end
    local a=it.aff
    if a.kind=="PROMPT" then return not a.prompt.Parent or a.prompt.Enabled==false end
    if a.kind=="CLICK" then return not a.click.Parent end
    if a.kind=="TOUCH" then return not a.part.Parent or not a.transmitter.Parent end
    return false
end
local function reachOf(a)
    if a.kind=="PROMPT" then return math.max(4,(a.prompt.MaxActivationDistance or 10)-1.5) end
    if a.kind=="CLICK" then return math.max(4,math.min(12,(a.click.MaxActivationDistance or 32)-2)) end
    return 2.5
end
local function interact(a,root)
    if a.kind=="PROMPT" then
        local f=exec("fireproximityprompt"); if not f then return false,"FIREPROXIMITYPROMPT_UNAVAILABLE" end
        local ok=pcall(function() f(a.prompt,math.max(a.prompt.HoldDuration or 0,0)) end); return ok,ok and "PROMPT_SENT" or "PROMPT_ERROR"
    elseif a.kind=="CLICK" then
        local f=exec("fireclickdetector"); if not f then return false,"FIRECLICKDETECTOR_UNAVAILABLE" end
        local ok=pcall(function() f(a.click) end); return ok,ok and "CLICK_SENT" or "CLICK_ERROR"
    elseif a.kind=="TOUCH" then
        -- movement onto the part is the primary touch; firetouchinterest only if the executor has it
        local f=exec("firetouchinterest")
        if f and root then pcall(function() f(root,a.part,0); task.wait(); f(root,a.part,1) end) end
        return true,"TOUCH_SENT"
    end
    return false,"INTERACTION_UNRESOLVED"
end

-- ---------------- diagnostics probe (bounded) ----------------
local function describe(inst)
    local bits={inst:GetFullName(),inst.ClassName}
    local p=posOf(inst); if p then table.insert(bits,string.format("(%.0f,%.0f,%.0f)",p.X,p.Y,p.Z)) end
    local ok,desc=pcall(function() return inst:GetDescendants() end)
    if ok then
        for i,d in ipairs(desc) do
            if i>80 then break end
            if d:IsA("ProximityPrompt") then table.insert(bits,string.format("prompt[%s|%s|en=%s|hold=%.2f|max=%.0f]",d.ActionText,d.ObjectText,tostring(d.Enabled),d.HoldDuration,d.MaxActivationDistance))
            elseif d:IsA("ClickDetector") then table.insert(bits,"click[max="..tostring(d.MaxActivationDistance).."]")
            elseif d.ClassName=="TouchTransmitter" then table.insert(bits,"touch["..(d.Parent and d.Parent.Name or "?").."]") end
        end
    end
    local oka,at=pcall(function() return inst:GetAttributes() end)
    if oka then local n=0; for k,v in pairs(at) do n=n+1; if n>5 then break end; table.insert(bits,"@"..tostring(k).."="..tostring(v)) end end
    return table.concat(bits," ")
end
local function buildProbe(reason)
    local S=S or LC.lastSession -- probe also works after the session ended
    if not S then return end
    local lines={"LOOT PROBE · "..tostring(reason).." · session #"..S.id,
        "boss: "..tostring(S.bossName).."  expected chest: "..tostring(S.expectedChest),
        string.format("death pos: (%.0f,%.0f,%.0f)",S.origin.X,S.origin.Y,S.origin.Z)}
    local ident=S.expectedChest and low(S.expectedChest) or nil
    local n=0; local seen={}
    for _,p in ipairs(partsNear(S.origin,lc().ChestIdentityRadius)) do
        local h=holderOf(p)
        if not seen[h] then
            seen[h]=true
            local nm=low(h.Name)..(h.Parent and (" "..low(h.Parent.Name)) or "")
            if hasAny(nm,CHEST_WORDS) or (ident and string.find(nm,ident,1,true)) then n=n+1; if n<=10 then table.insert(lines,"chest-like: "..describe(h)) end end
        end
    end
    if n==0 then table.insert(lines,"chest-like: none within "..lc().ChestIdentityRadius.." studs") end
    local u=0
    for _,it in pairs(S.items) do if not it.done or it.unverified then u=u+1; if u<=10 then table.insert(lines,"drop "..(it.unverified and "UNVERIFIED" or "PENDING")..": "..describe(it.holder)) end end end
    LC.probe=table.concat(lines,"\n")
end
-- NO_LOOT_PROBE only when no loot session has started since boot; otherwise build one on demand
local function ensureProbe() if not LC.probe and (S or LC.lastSession) then buildProbe("ON_DEMAND · "..tostring(LC.state)) end end
function RAVYN:GetLootProbe() ensureProbe(); return result(LC.probe~=nil,"LOOT_PROBE",LC.probe or "NO_LOOT_PROBE") end
function RAVYN:CopyLootProbe()
    ensureProbe()
    local f=exec("setclipboard"); if not LC.probe then return result(false,"NO_LOOT_PROBE") end
    if not f then return result(false,"SETCLIPBOARD_UNAVAILABLE") end
    pcall(f,LC.probe); return result(true,"LOOT_PROBE_COPIED")
end

-- ---------------- chest identity search ----------------
local function findChest(center,identity,radius)
    local ident=identity and low(identity) or nil
    local best,bd=nil,math.huge; local seen={}
    for i,p in ipairs(partsNear(center,radius)) do
        if i>1500 then break end
        local cur=p; local match=nil
        for _=1,6 do
            if not cur or cur==workspace then break end
            local nm=low(cur.Name)
            if ident and nm==ident then match=cur; break end
            if not ident and hasAny(nm,CHEST_WORDS) then match=cur; break end
            cur=cur.Parent
        end
        if not match and ident then
            local pr=p:FindFirstChildWhichIsA("ProximityPrompt",true)
            if pr and string.find(promptText(pr),ident,1,true) then match=holderOf(p) end
        end
        if match and not seen[match] and not isPlayerOrNpc(match) then
            seen[match]=true
            local pos=posOf(match); local d=pos and (pos-center).Magnitude or math.huge
            if d<bd then best,bd=match,d end
        end
    end
    return best,bd
end

-- ---------------- session lifecycle ----------------
local function publish()
    if not S then return end
    local det,att,col,unv=0,0,0,0
    for _,it in pairs(S.items) do det=det+1; if it.attempts>0 then att=att+1 end; if it.collected then col=col+1 end; if it.unverified then unv=unv+1 end end
    LC.detected=det; LC.attempted=att; LC.collected=col; LC.unverified=unv; LC.remaining=det-col-unv
    LC.bossName=S.bossName; LC.expectedChest=S.expectedChest
    local ch=S.chest
    LC.chestState=ch and ch.state or (S.expectedChest and "—" or "NONE EXPECTED")
    LC.chestPath=ch and ch.holder and ch.holder:GetFullName() or nil
    LC.chestInteraction=ch and ch.aff and ch.aff.kind or (ch and ch.holder and "UNKNOWN") or nil
    LC.chestDistance=ch and ch.dist or nil
end
local function finish(code,kind)
    if not S then return end
    publish()
    local summary=string.format("%s · %d/%d collected%s",code,LC.collected,LC.detected,LC.unverified>0 and (" · "..LC.unverified.." unverified") or "")
    if S.bossName then summary=S.bossName.." · "..summary end
    if LC.unverified>0 or kind=="warn" then buildProbe(code) end
    LC.lastResult=summary; event(summary,kind or "success")
    LC.lastSession=S; S=nil; LC.active=false; LC.state="COMPLETE"; LC.priority=0
    local sid=LC.sessionId
    task.delay(1.5,function() if LC.sessionId==sid and not LC.active then LC.state="IDLE" end end)
end
local function begin(kind,origin,priority,baseline,radius,timeout,ctx)
    local now=os.clock()
    LC.sessionId=LC.sessionId+1; LC.sessions=LC.sessions+1
    S={id=LC.sessionId,kind=kind,origin=origin,priority=priority,startedAt=now,lastNewAt=now,lastTickAt=now,preemptedFor=0,
        timeout=timeout or lc().LootSessionTimeout,items={},zones={},chest=nil,bossName=ctx and ctx.bossName,expectedChest=ctx and ctx.chest,lastScanAt=0,
        deathTime=ctx and ctx.deathTime,source=ctx and ctx.source}
    local strict=kind=="QUEST_KILL"
    local zone={center=origin,radius=radius or lc().KillLootRadius,baseline=baseline or baselineSet(origin,radius or lc().KillLootRadius),nearby=(not strict) and lc().CollectNearbyLoot}
    zone.baselineSource=baseline and "PRE_KILL" or "POST_DEATH_FALLBACK"
    table.insert(S.zones,zone)
    if S.expectedChest then S.chest={state="SEARCHING",since=now,attempts=0,firedAt=0} end
    LC.active=true; LC.kind=kind; LC.priority=priority; LC.failReason=nil; LC.probe=nil; LC.state="STARTING"
    publish()
end
-- ctx (optional) = {bossName=, chest=BossInfo.Chest, rarity=}
function RAVYN:StartKillLoot(pos,isBoss,baseline,quest,ctx)
    if not lc().AutoLootAfterKill or not pos then return result(false,"LOOT_SKIPPED") end
    local prio=quest and P.QUEST_IMMEDIATE_LOOT or (isBoss and P.BOSS_LOOT or (P.NORMAL_FARM+2))
    if LC.active then
        if (LC.priority or 0)>=prio then return result(false,"LOOT_BUSY") end
        event("Loot session replaced by higher priority kill loot","info"); S=nil; LC.active=false
    end
    if quest then begin("QUEST_KILL",pos,prio,baseline,lc().QuestLootRadius,lc().QuestLootTimeout,nil)
    elseif isBoss then begin("BOSS",pos,prio,baseline,nil,(ctx and ctx.chest) and lc().BossLootTimeout or lc().LootSessionTimeout,ctx)
    else begin("KILL",pos,prio,baseline,nil,nil,nil) end
    if isBoss then event("Boss defeated · "..tostring(ctx and ctx.bossName or "?")..(ctx and ctx.chest and (" · expecting "..ctx.chest) or ""),"info") end
    return result(true,"LOOT_SESSION_STARTED",{kind=S.kind,baseline=S.zones[1].baselineSource})
end

local function chestStep(now,root)
    local ch=S.chest
    if ch.state=="SEARCHING" then
        if now-(ch.lastSearch or 0)<.4 then return false end
        ch.lastSearch=now
        local h,d=findChest(S.origin,S.expectedChest,lc().ChestIdentityRadius)
        if h then
            ch.holder=h; ch.dist=d; ch.pos=posOf(h); ch.aff=affordance(h)
            if ch.aff then ch.state="CHEST_FOUND"; event("Chest found · "..h.Name..string.format(" · %.0f studs",d),"info")
            else ch.state="INTERACTION_UNRESOLVED"; LC.failReason="CHEST_INTERACTION_UNRESOLVED"; buildProbe("CHEST_INTERACTION_UNRESOLVED") end
        elseif now-ch.since>lc().ChestSpawnWait then
            ch.state="NOT_FOUND"; LC.failReason="CHEST_NOT_FOUND"; buildProbe("CHEST_NOT_FOUND")
        end
        return false
    end
    if ch.state=="CHEST_FOUND" or ch.state=="TRAVEL_TO_CHEST" or ch.state=="OPEN_SENT" then
        if not ch.holder.Parent then ch.state="OPEN_VERIFIED"; ch.evidence="CHEST_REMOVED"; return false end
        local reach=reachOf(ch.aff); local d=(root.Position-ch.pos).Magnitude
        if d>reach then ch.state="TRAVEL_TO_CHEST"; requestTravel(ch.pos+Vector3.new(0,2,0),"CHEST","chest:"..S.id,.5); return true end
        if ch.state~="OPEN_SENT" or (now-ch.firedAt>1.2 and ch.attempts<3) then
            if ch.attempts==0 then
                -- pre-open baseline: anything appearing near the chest after this is a chest drop
                table.insert(S.zones,{center=ch.pos,radius=lc().ChestDropRadius,baseline=baselineSet(ch.pos,lc().ChestDropRadius),nearby=false,chestZone=true})
                ch.attrSig=describe(ch.holder)
            end
            local ok,code=interact(ch.aff,root)
            if not ok then ch.state="INTERACTION_UNRESOLVED"; LC.failReason=code; buildProbe(code); return false end
            ch.attempts=ch.attempts+1; ch.firedAt=now; ch.state="OPEN_SENT"
            return true
        end
        -- verification: affordance gone / structure changed / chest drops appeared
        local gone=(ch.aff.kind=="PROMPT" and (not ch.aff.prompt.Parent or ch.aff.prompt.Enabled==false)) or (ch.aff.kind=="CLICK" and not ch.aff.click.Parent)
        if gone then ch.state="OPEN_VERIFIED"; ch.evidence="AFFORDANCE_GONE"
        elseif describe(ch.holder)~=ch.attrSig then ch.state="OPEN_VERIFIED"; ch.evidence="STATE_CHANGED"
        elseif ch.attempts>=3 and now-ch.firedAt>1.5 then ch.state="OPEN_UNVERIFIED"; LC.failReason="CHEST_OPEN_UNVERIFIED"; buildProbe("CHEST_OPEN_UNVERIFIED") end
        if ch.state=="OPEN_VERIFIED" then event("Chest opened · verified ("..tostring(ch.evidence)..")","success"); S.lastNewAt=now end
        return ch.state=="OPEN_SENT"
    end
    return false
end
local function collectStep(now,root)
    if now-S.lastScanAt>=lc().LootRescanInterval then
        S.lastScanAt=now
        for _,zone in ipairs(S.zones) do
            for _,c in ipairs(newCandidates(zone,S.chest and S.chest.holder)) do
                if not S.items[c.holder] then
                    S.items[c.holder]={holder=c.holder,aff=c.aff,pos=c.pos,attempts=0,firedAt=0,arrivedAt=nil,done=false}
                    S.lastNewAt=now
                    if zone.chestZone and S.chest and S.chest.state=="OPEN_UNVERIFIED" then S.chest.state="OPEN_VERIFIED"; S.chest.evidence="DROPS_APPEARED"; LC.failReason=nil end
                end
            end
        end
    end
    local pending,nearest,nd={},nil,math.huge
    for _,it in pairs(S.items) do
        if not it.done then
            if affGone(it) then
                it.done=true
                if it.attempts>0 then it.collected=true; LC.totalCollected=LC.totalCollected+1 end
            elseif it.attempts>=3 and now-it.firedAt>.8 then it.done=true; it.unverified=true
            else
                table.insert(pending,it)
                local d=(root.Position-it.pos).Magnitude; if d<nd then nearest,nd=it,d end
            end
        end
    end
    if not nearest then return 0 end
    local reach=reachOf(nearest.aff)
    if nd>reach then requestTravel(nearest.pos+Vector3.new(0,nearest.aff.kind=="TOUCH" and 0 or 2,0),"LOOT","loot:"..S.id..":"..tostring(nearest.holder),.5); return #pending end
    -- cluster: act on every pending drop already within reach, no per-item travel
    for _,it in ipairs(pending) do
        local r=reachOf(it.aff)
        if (root.Position-it.pos).Magnitude<=r+.5 then
            if it.aff.kind=="TOUCH" then
                it.arrivedAt=it.arrivedAt or now
                if now-it.arrivedAt>.6 and now-it.firedAt>.6 then it.attempts=it.attempts+1; it.firedAt=now; interact(it.aff,root) end
            elseif now-it.firedAt>.35 then
                local ok,code=interact(it.aff,root)
                if not ok then LC.failReason=code; it.done=true; it.unverified=true else it.attempts=it.attempts+1; it.firedAt=now end
            end
        end
    end
    return #pending
end

local function discoverChest(now,root)
    if not lc().AutoLootChests or now-LC.lastChestScanAt<lc().ChestScanInterval then return end
    LC.lastChestScanAt=now
    local h,d=findChest(root.Position,nil,lc().ChestSearchRadius)
    if not h or d>lc().ChestSearchRadius then return end
    local key=h:GetFullName(); if (LC.chestBackoff[key] or 0)>now then return end
    local aff=affordance(h); if not aff then return end
    local prio=d<=lc().ImmediateChestRadius and P.IMMEDIATE_LOOT or P.GENERAL_LOOT
    local JS=RAVYN.JobScheduler
    if JS and JS.job~="IDLE" and prio<=(JS.priority or 0) then return end
    LC.chestBackoff[key]=now+60
    begin("CHEST",posOf(h) or root.Position,prio,nil,lc().ChestDropRadius,lc().LootSessionTimeout,nil)
    S.chest={state="CHEST_FOUND",holder=h,dist=d,pos=posOf(h),aff=aff,attempts=0,firedAt=0,since=now}
    event(string.format("Chest found · %s · %.0f studs",h.Name,d),"info")
end

local function tick()
    local now=os.clock()
    if not (RAVYN.FSM and RAVYN.FSM.state=="RUNNING") then if LC.active then S=nil; LC.active=false; LC.state="IDLE" end; return end
    -- v1.2: while BossLootController V2 owns a boss-chest session, the generic (v3.8.4.2) path stays idle
    if LC.v2Active then return end
    local root=liveRoot(); if not root then return end
    if LC.active and S then
        local dt=now-(S.lastTickAt or now); S.lastTickAt=now
        local JS=RAVYN.JobScheduler
        if JS and JS.job~="LOOT" and (JS.priority or 0)>S.priority then
            S.startedAt=S.startedAt+dt; S.lastNewAt=S.lastNewAt+dt; S.preemptedFor=S.preemptedFor+dt
            if S.chest and S.chest.since then S.chest.since=S.chest.since+dt end
            LC.state="PAUSED · "..tostring(JS.job)
            if S.preemptedFor>lc().MaxPreemptedSeconds then finish("LOOT_PREEMPTED_EXPIRED","warn") end
            return
        end
        if now-S.startedAt>S.timeout then finish("LOOT_TIMEOUT","warn"); return end
        if now-S.startedAt<lc().LootSpawnWait then LC.state="STARTING"; publish(); return end
        local ch=S.chest
        local pending=collectStep(now,root)
        local chestBusy=false
        if pending==0 and ch then chestBusy=chestStep(now,root) end
        publish()
        local chestSettled=(not ch) or ch.state=="OPEN_VERIFIED" or ch.state=="OPEN_UNVERIFIED" or ch.state=="NOT_FOUND" or ch.state=="INTERACTION_UNRESOLVED"
        local chestLabel={SEARCHING="SEARCHING_CHEST",CHEST_FOUND="CHEST_FOUND",TRAVEL_TO_CHEST="TRAVELING",OPEN_SENT="OPENING"}
        if pending>0 then LC.state=string.format("COLLECTING %d / %d",LC.collected,LC.detected)
        elseif ch and not chestSettled then LC.state=chestLabel[ch.state] or ch.state
        elseif ch and ch.state=="NOT_FOUND" then LC.state="CHEST_NOT_FOUND"
        elseif ch and ch.state=="OPEN_UNVERIFIED" then LC.state="OPEN_UNVERIFIED"
        else LC.state="DETECTING_DROPS" end
        if pending==0 and not chestBusy and chestSettled and now-S.lastNewAt>=lc().LootQuietWindow then
            local warn=(ch and ch.state~="OPEN_VERIFIED") or LC.unverified>0
            finish(LC.detected==0 and (ch and ch.state~="OPEN_VERIFIED" and (ch.state=="NOT_FOUND" and "CHEST_NOT_FOUND" or "CHEST_"..ch.state) or "NO_DROPS_DETECTED") or "LOOT COMPLETE",warn and "warn" or "success")
        end
        return
    end
    local ap=RAVYN.Config.Intelligence and RAVYN.Config.Intelligence.AutoPlay
    local JS=RAVYN.JobScheduler
    if ap and not (JS and JS.job~="IDLE" and (JS.priority or 0)>=P.IMMEDIATE_LOOT) then discoverChest(now,root) end
end
function RAVYN:SetLootOption(key,value)
    local allowed={AutoLootAfterKill=true,AutoLootChests=true,CollectNearbyLoot=true}
    if not allowed[key] or type(value)~="boolean" then return result(false,"INVALID_LOOT_OPTION") end
    return self:SetConfig("Loot384."..key,value)
end
function RAVYN:GetLootStatus()
    publish()
    return result(true,"LOOT_STATUS",{active=LC.active,state=LC.state,kind=LC.kind,detected=LC.detected,attempted=LC.attempted,collected=LC.collected,
        unverified=LC.unverified,remaining=LC.remaining,boss=LC.bossName,expectedChest=LC.expectedChest,chest=LC.chestState,chestPath=LC.chestPath,
        chestInteraction=LC.chestInteraction,lastResult=LC.lastResult,failReason=LC.failReason,
        bindings={prompt=exec("fireproximityprompt") and "AVAILABLE" or "UNAVAILABLE",click=exec("fireclickdetector") and "AVAILABLE" or "UNAVAILABLE",touch=exec("firetouchinterest") and "AVAILABLE" or "MOVEMENT_ONLY"}})
end
LC.token=(LC.token or 0)+1
local token=LC.token
task.spawn(function()
    while not RAVYN._destroyed and LC.token==token do
        local ok,err=pcall(tick)
        if not ok then RAVYN.Logger:log("ERROR","LOOT_TICK",{error=tostring(err)}); if S then finish("LOOT_ERROR","warn") end end
        task.wait(.12)
    end
end)
local baseStop=RAVYN.Stop
function RAVYN:Stop() S=nil; LC.sessionId=LC.sessionId+1; LC.active=false; LC.state="IDLE"; LC.priority=0; return baseStop(self) end
local baseDestroy=RAVYN.Destroy
function RAVYN:Destroy() LC.token=LC.token+1; S=nil; LC.active=false; return baseDestroy(self) end
CTX["LC"]=LC
RAVYN.Logger:log("INFO","LOOT_CONTROLLER_V3842_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("AutoPlayV384.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local targetBasis=CTX["targetBasis"]
local targetModel=CTX["targetModel"]
local humanoidOf=CTX["humanoidOf"]
-- v3.8.4 AutoPlay orchestration glue (outermost tick wrapper).
-- Decision chain stays: JobScheduler → AutoPlayV38 → V37. This layer only adds:
--   * learned quest-target overrides (QuestTargetMemory) when quest text has no NPC name
--   * verified kill detection → kill-loot session handoff
--   * session counters / activity feed for the UI
local AP={kills=0,bossKills=0,startedAt=nil,prev=nil,feed={},lastActivity="IDLE",lostTargets=0,lastKillEvidence=nil}
RAVYN.AutoPlay384=AP
local function feed(text,kind)
    table.insert(AP.feed,{at=os.clock(),clock=os.date("%H:%M:%S"),text=text,kind=kind or "info"})
    while #AP.feed>60 do table.remove(AP.feed,1) end
end
AP.push=feed
-- mirror important log lines into the live feed (bounded, deduplicated by message)
do
    local L=RAVYN.Logger; local baseLog=L.log; local last=nil
    -- v3.9: meaningful events only (no per-M1 / per-skill-attempt / per-owner-flip entries)
    local keep={"QUEST · ","LOOT · ","TRAVEL_STUCK","ADAPTIVE_LOADOUT_CHANGED","SKILL_VERIFIED_","RECOVERY_STARTED","TARGET_ACQUIRED"}
    function L:log(level,message,meta)
        baseLog(self,level,message,meta)
        local m=tostring(message)
        if m~=last then
            for _,k in ipairs(keep) do
                if string.sub(m,1,#k)==k then last=m; feed(m,level=="WARN" and "warn" or (level=="ERROR" and "error" or "info")); break end
            end
        end
    end
end

local function snapshotEntity(id)
    for _,e in ipairs((RAVYN.Features.snapshot or {}).npcs or {}) do if e.id==id then return e end end
    return nil
end

local readBossMeta=CTX["readBossMeta"]
RAVYN.Version="Direct-v1.0-foundation"
RAVYN.Build="2026-09-27-direct-v1-foundation"
-- ================= TargetCombatSession (v3.8.4.3) =================
-- One session per RAVYN-locked target. Everything loot needs (name, BossInfo.Chest, rarity, last position/HP)
-- is cached WHILE ALIVE, so death resolution never depends on the model still existing.
-- Death sources: Humanoid.Died (queued, never acted on inside the callback) · Health<=0 · removal after low HP.
-- Resolution runs BEFORE the base tick, so no next target can be selected between death and loot start.
local H={listener="NONE",session=nil,deathBy=nil,handled=false,context="NONE",startCalled=false,startResult=nil,lastAt=nil,lastBoss=nil,resolutions=0}
AP.handoff=H; AP.token=0
local TCS=nil
local deathQueue=nil -- {token=,by=,at=}
local function lootEnabled(self)
    local l=self.Config.Loot384
    return l and l.AutoLootAfterKill==true and self.FSM and self.FSM.state=="RUNNING"
end
local function closeSession(reason)
    if TCS and TCS.conn then pcall(function() TCS.conn:Disconnect() end) end
    if TCS then RAVYN.Logger:log("INFO","TARGET_SESSION_CLOSED",{name=TCS.name,reason=reason}) end
    TCS=nil; H.listener="NONE"; AP.deathPending=false
end
AP.closeSession=closeSession
local function attachDied(s)
    if s.conn or not s.hum then return end
    local tok=s.token
    local ok,conn=pcall(function()
        return s.hum.Died:Connect(function()
            if TCS and TCS.token==tok and not TCS.deathHandled and not deathQueue then deathQueue={token=tok,by="HUMANOID_DIED",at=os.clock()} end
        end)
    end)
    if ok and conn then s.conn=conn; H.listener="ATTACHED" end
end
local function farmSource(self)
    if self.Config.Intelligence and self.Config.Intelligence.AutoPlay then return "AUTO_PLAY" end
    if self.Config.Farm.Boss.Enabled then return "MANUAL_BOSS_FARM" end
    if self.Config.Farm.NormalMobs.Enabled then return "MANUAL_MOB_FARM" end
    if self.Config.Intelligence.KillAura and self.Config.Intelligence.KillAura.Enabled then return "KILL_AURA" end
    return "MANUAL"
end
local function openSession(self,t,now)
    AP.token=AP.token+1
    TCS={token=AP.token,id=t.id,name=t.name,boss=t.isBoss==true or t.classification=="BOSS",createdAt=now,lastSeenAt=now,
        baselineAt=-math.huge,lastRavynAttackAt=nil,deathHandled=false,source=farmSource(self),metaRead=false}
    H.session=TCS.token; H.handled=false; H.deathBy=nil; H.context="NONE"; H.startCalled=false; H.startResult=nil
    if TCS.boss then RAVYN.Logger:log("INFO","TARGET_ACQUIRED · "..tostring(t.name),{}) end
    return TCS
end
local function refreshSession(self,s,t,now)
    s.lastSeenAt=now; s.name=t.name
    local p=targetBasis(t); if p then s.lastPos=p end
    if t.health and t.maxHealth and t.maxHealth>0 then s.lastHealth=t.health; s.maxHealth=t.maxHealth; s.hpPct=t.health/t.maxHealth*100 end
    local MO=self.MoveOwner; if MO and MO.liveDistance then s.lastDistance=MO.liveDistance elseif t.distance then s.lastDistance=t.distance end
    if not s.model then
        local okM,model=pcall(targetModel)
        if okM and model then s.model=model; local okH,h=pcall(humanoidOf,model); if okH then s.hum=h end end
    end
    attachDied(s)
    if s.hum then local okH,h=pcall(function() return s.hum.Health end); if okH and tonumber(h) then s.humHealth=h end end
    local la=math.max(LiveAction.lastAttack or -math.huge,LiveAction.lastSkill or -math.huge)
    if la>=s.createdAt then s.lastRavynAttackAt=la end
    if s.boss and not s.metaRead and readBossMeta then
        local okB,meta=pcall(readBossMeta,t.id,t.name)
        if okB and meta and meta.read then s.metaRead=true; s.chest=meta.chest; s.chestRarity=meta.chestRarity end
    end
    -- pre-kill loot baseline around the living target (frozen at the first death sign)
    local dying=(t.alive==false) or (s.hpPct~=nil and s.hpPct<=0) or (s.humHealth~=nil and s.humHealth<=0)
    local LC=self.LootController; local lcfg=self.Config.Loot384
    if not dying and lootEnabled(self) and LC and LC.baselineSet and s.lastPos and now-s.baselineAt>=.5 then
        s.baselineAt=now
        local okS,set=pcall(LC.baselineSet,s.lastPos,math.max(lcfg.KillLootRadius or 26,lcfg.QuestLootRadius or 18)+10)
        if okS and set then s.baseline=set end
    end
end
-- returns evidence code or nil; "PENDING" while a removal is being resolved
local function deathEvidence(s,now)
    if deathQueue and deathQueue.token==s.token then return "HUMANOID_DIED" end
    if s.hum then local okH,h=pcall(function() return s.hum.Health end); if okH and tonumber(h) and h<=0 then return "HEALTH_ZERO" end end
    local e=snapshotEntity(s.id)
    if e and (e.alive==false or (tonumber(e.health) or 1)<=0) then return "HEALTH_ZERO" end
    local removed=(s.model and not s.model.Parent) or (s.hum and not s.hum.Parent) or (not e and now-s.lastSeenAt>.05)
    if removed then
        -- removal counts as death only right after RAVYN hit a low-HP target at close range (not a stream-out)
        local close=(s.lastDistance or math.huge)<=60
        local recent=s.lastRavynAttackAt and now-s.lastRavynAttackAt<=3
        if close and recent and (s.hpPct or 100)<=12 then return "OTHER:REMOVED_AFTER_LOW_HP" end
        if close and (s.hpPct or 100)<=25 and now-s.lastSeenAt<1 then return "PENDING" end
        return "LOST"
    end
    return nil
end
local function handleDeath(self,s,by,now)
    s.deathHandled=true; deathQueue=nil; AP.deathPending=true
    AP.deadIds=AP.deadIds or {}; AP.deadIds[s.id]=now -- v1.2: a stale snapshot must not re-open (and re-count) this death
    H.deathBy=by; H.handled=true; H.lastAt=now; H.lastBoss=s.boss and s.name or nil; H.resolutions=H.resolutions+1
    AP.kills=AP.kills+1; if s.boss then AP.bossKills=AP.bossKills+1 end; AP.lastKillEvidence=by
    local JS=self.JobScheduler; local questKill=JS and JS.job=="ACTIVE_QUEST" or false
    feed("Kill · "..tostring(s.name)..(questKill and " · quest" or "")..(s.boss and " · boss" or "").." · "..by,"success")
    if lootEnabled(self) and self.StartKillLoot then
        local chest=s.chest
        if s.boss and not chest and self.BossMeta and self.BossMeta.byName[s.name] then chest=self.BossMeta.byName[s.name].chest end
        local ctx=s.boss and {bossName=s.name,bossId=s.id,chest=chest,rarity=s.chestRarity,deathPosition=s.lastPos,deathTime=now,source=s.source} or nil
        H.context=ctx and "CREATED" or "NONE (not a boss)"
        H.startCalled=true
        local okS,r=pcall(function() return self:StartKillLoot(s.lastPos,s.boss,s.baseline,questKill,ctx) end)
        H.startResult=okS and (r and r.code or "nil") or ("ERROR "..tostring(r))
    else
        H.startCalled=false; H.startResult=lootEnabled(self) and "NO_LOOT_CONTROLLER" or "AUTO_LOOT_AFTER_KILL_OFF"
    end
    if self.QuestBrain and self.QuestBrain.onKill then pcall(self.QuestBrain.onKill,s) end
    AP.deathPending=false
    closeSession("DEATH_"..by)
end
AP.sessionInfo=function() return TCS end

local baseTick=RAVYN._tick
function RAVYN:_tick()
    local ap=self.Config.Intelligence and self.Config.Intelligence.AutoPlay
    local now0=os.clock()
    -- 1) resolve the current target session BEFORE any new target can be chosen
    if TCS and not TCS.deathHandled then
        local ev=deathEvidence(TCS,now0)
        if ev=="PENDING" then AP.deathPending=true
        elseif ev=="LOST" then AP.lostTargets=AP.lostTargets+1; closeSession("LOST")
        elseif ev then handleDeath(self,TCS,ev,now0)
        else AP.deathPending=false end
    end
    local QB=self.QuestBrain; local A=self.AdaptiveIntel; local q=A and A.quest
    -- learned target override (only when quest text did not name the target)
    local saved=nil
    if ap and QB and q and q.state=="ACTIVE" and q.objectiveType=="KILL" and not q.targetName and QB.learnedTarget then
        local name,conf,e=QB.learnedTarget(q)
        if not (name and e) and QB.markerTarget then
            -- marker evidence: the NPC a quest marker is attached to (must be streamed and alive)
            for _,x in ipairs((self.Features.snapshot or {}).npcs or {}) do if x.name==QB.markerTarget and x.alive~=false then name,e=x.name,x; break end end
        end
        if name and e then
            local boss=e.isBoss==true or e.classification=="BOSS"
            saved={mode=self.Config.AutoPlayV38.Mode,mob=self.Config.Farm.NormalMobs.TargetName,boss=self.Config.Farm.Boss.TargetName}
            self.Config.AutoPlayV38.Mode=boss and "Bosses" or "Mobs"
            if boss then self.Config.Farm.Boss.TargetName=name else self.Config.Farm.NormalMobs.TargetName=name end
            QB.learnedOverride=name
        else QB.learnedOverride=nil end
    elseif QB then QB.learnedOverride=nil end
    local ok,err=pcall(baseTick,self)
    if saved then self.Config.AutoPlayV38.Mode=saved.mode; self.Config.Farm.NormalMobs.TargetName=saved.mob; self.Config.Farm.Boss.TargetName=saved.boss end
    -- 2) track the (possibly new) target. A session is only replaced when its death/loss is resolved
    --    or when a different LIVE target is locked while the old one is still alive (retarget).
    local now=os.clock()
    local t=LiveAction.target
    -- v1.2: the NPC snapshot refreshes every ~0.3 s; a target resolved dead moments ago is dropped, not re-engaged
    if t and t.id and AP.deadIds and AP.deadIds[t.id] and now-AP.deadIds[t.id]<10 then
        LiveAction.target=nil; LiveAction.targetId=nil; t=nil
    end
    if t and t.id then
        if TCS and TCS.id~=t.id and not TCS.deathHandled then
            local ev=deathEvidence(TCS,now)
            if ev and ev~="LOST" and ev~="PENDING" then handleDeath(self,TCS,ev,now) else closeSession("RETARGET") end
        end
        if not TCS then openSession(self,t,now) end
        if TCS and TCS.id==t.id then refreshSession(self,TCS,t,now) end
    end
    AP.prev=TCS
    if not ok then error(err) end
end

local baseSetAutoPlay=RAVYN.SetAutoPlay
function RAVYN:SetAutoPlay(v)
    local r=baseSetAutoPlay(self,v)
    if r and r.ok then
        if v then AP.startedAt=os.clock(); feed("Auto Play enabled","success")
        else
            feed("Auto Play disabled","info")
            if self.QuestBrain then self.QuestBrain.navigating=false; self.QuestBrain.learnedOverride=nil end
            if self.LootController then self.LootController.active=false; self.LootController.state="IDLE" end
        end
    end
    return r
end
function RAVYN:GetAutoPlay384Status()
    local JS=self.JobScheduler or {}; local MO=self.MoveOwner or {}
    return result(true,"AUTOPLAY_384_STATUS",{enabled=self.Config.Intelligence.AutoPlay==true,job=JS.job,overlay=JS.overlay,priority=JS.priority,
        movement=MO.current,kills=AP.kills,bossKills=AP.bossKills,target=LiveAction.target and LiveAction.target.name,
        unresolved={perfectParry="EVIDENCE_REQUIRED",instakill="UNRESOLVED_GAME_BINDING",equip="EQUIP_BINDING_UNRESOLVED",nonKillObjectives="UNRESOLVED_GAME_BINDING"}})
end
local baseStopAP=RAVYN.Stop
function RAVYN:Stop() closeSession("STOP"); deathQueue=nil; return baseStopAP(self) end
local baseDestroyAP=RAVYN.Destroy
function RAVYN:Destroy() closeSession("DESTROY"); deathQueue=nil; return baseDestroyAP(self) end
CTX["AP384"]=AP
RAVYN.Logger:log("INFO","AUTOPLAY_V384_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("CombatMobilityV384.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Util=CTX["Util"]
local Config=CTX["Config"]
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local Brain=CTX["Brain"]
local liveRoot=CTX["liveRoot"]
local liveHumanoid=CTX["liveHumanoid"]
local targetBasis=CTX["targetBasis"]
local currentSkillKeys=CTX["currentSkillKeys"]
local cancelTween=CTX["cancelTween"]
local rawTargetRoot=CTX["rawTargetRoot"]
-- v3.8.4 Combat Hover + single combat executor.
-- Hover runs ONLY while MoveOwner is COMBAT_HOVER or RECOVERY (never from travel distance).
-- DEFENSE releases the movers so CombatEvolution dodges are not cancelled by BodyVelocity.
local defaults={
    Enabled=true, FlyFarmFight=true,
    HoverMode="ABOVE_BEHIND", FlyHeight=5.5, HoverDistance=3.0, FlyBehindOffset=2.5, OrbitRadius=4.5, OrbitSpeed=1.6,
    FlySpeed=110, VerticalSpeed=70, PositionGain=9,
    -- v3.9: Adaptive M1 by default. CombatSpeed maps to internal parameters; CUSTOM uses the raw values below.
    CombatSpeed="FAST", TurboM1=false, M1Version=2, M1Interval=.14, HoldCombo=true, ComboLength=3,
    AggressiveSkills=true, SkillInterval=.48, SkillCastLock=.45, SkillBackoff=8, ConservativeRetry=3,
    RecoveryDistance=40, RecoveryHeight=22, RecoveryStrafeSpeed=.35,
    KeepComboUnderHit=true,
    NoRagdoll=true, NoStun=false, NoKnockback=false, NoAttackSlowdown=false,
    AntiRagdoll=true, AntiStun=false, -- legacy keys kept for saved settings compatibility
}
Config.Default.CombatMobility=Util.deepCopy(defaults)
local saved=RAVYN.Config.CombatMobility or {}
-- Turbo M1 used to be ON by default (not a user choice) and is confirmed to flicker the menu → reset once
if (tonumber(saved.M1Version) or 0)<2 then saved.TurboM1=false; saved.M1Version=2; if (tonumber(saved.M1Interval) or 0)<.12 then saved.M1Interval=.14 end end
if saved.NoRagdoll==nil and saved.AntiRagdoll~=nil then saved.NoRagdoll=saved.AntiRagdoll end
if saved.NoStun==nil and saved.AntiStun~=nil then saved.NoStun=saved.AntiStun end
RAVYN.Config.CombatMobility=Util.deepMerge(defaults,saved)
local modes={ABOVE=true,ABOVE_BEHIND=true,ORBIT_HOVER=true}
if not modes[RAVYN.Config.CombatMobility.HoverMode] then RAVYN.Config.CombatMobility.HoverMode="ABOVE_BEHIND" end

local M={flightActive=false,hoverState="STANDBY",lastAction="READY",
    m1Attempts=0,m1Sent=0,m1Count=0,skillAttempts=0,skillSent=0,skillCount=0,lastSkillKey=nil,lastSkillAt=0,
    skillFailReason="IDLE",skillsDiscovered=0,recoveries=0,mitigation={ragdoll=0,stun=0,knockback=0,slowdown="NOT_OBSERVED"},
    comboStage=0,token=0,lastStunSweep=0,recoveryState="STANDBY",escapeDir=nil,bodyVelocity=nil,bodyGyro=nil,root=nil,orbitAngle=0}
RAVYN.CombatMobility=M
local function cfg() return RAVYN.Config.CombatMobility end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
-- Combat Speed → internal parameters (normal users never see the raw values)
local SPEED={SAFE={m1=.18,skill=.8,combo=3},FAST={m1=.14,skill=.5,combo=3},MAX={m1=.12,skill=.35,combo=2}}
local function params()
    local c=cfg(); local sp=SPEED[c.CombatSpeed]
    if not sp then return {m1=math.max(.05,tonumber(c.M1Interval) or .14),skill=math.max(.25,tonumber(c.SkillInterval) or .48),combo=math.max(1,tonumber(c.ComboLength) or 3)} end
    local m1=sp.m1; if c.TurboM1 then m1=.09 end -- experimental, developer only
    return {m1=m1,skill=sp.skill,combo=sp.combo}
end
M.params=params
local function owner() local MO=RAVYN.MoveOwner; return MO and MO.current or "IDLE" end

local function destroyMover()
    for _,x in ipairs({M.bodyVelocity,M.bodyGyro}) do if x then pcall(function() x:Destroy() end) end end
    M.bodyVelocity=nil; M.bodyGyro=nil; M.root=nil; M.flightActive=false
end
local function ensureMover(root)
    if M.root~=root then destroyMover(); M.root=root end
    if not M.bodyVelocity or M.bodyVelocity.Parent~=root then
        local old=root:FindFirstChild("RAVYN_CombatFlightVelocity"); if old then pcall(function() old:Destroy() end) end
        local bv=Instance.new("BodyVelocity"); bv.Name="RAVYN_CombatFlightVelocity"; bv.MaxForce=Vector3.new(1e8,1e8,1e8); bv.P=12000; bv.Velocity=Vector3.zero; bv.Parent=root; M.bodyVelocity=bv
    end
    if not M.bodyGyro or M.bodyGyro.Parent~=root then
        local old=root:FindFirstChild("RAVYN_CombatFlightGyro"); if old then pcall(function() old:Destroy() end) end
        local bg=Instance.new("BodyGyro"); bg.Name="RAVYN_CombatFlightGyro"; bg.MaxTorque=Vector3.new(0,1e8,0); bg.P=22000; bg.D=850; bg.CFrame=root.CFrame; bg.Parent=root; M.bodyGyro=bg
    end
end
local function hoverAllowed()
    local c=cfg()
    if not c.Enabled or not c.FlyFarmFight then return false end
    if not RAVYN.FSM or RAVYN.FSM.state~="RUNNING" then return false end
    local o=owner()
    return (o=="COMBAT_HOVER" or o=="RECOVERY") and LiveAction.target~=nil and LiveAction.target.alive~=false
end
-- target-relative hover point: follows target X/Y/Z, sits above (and slightly behind) it
local function hoverPoint(target,now,dt)
    local tp,look=targetBasis(target)
    if not tp then return nil end
    local c=cfg(); local profile=Hooks.activeProfile()
    look=look or Vector3.new(0,0,-1)
    local flatLook=Vector3.new(look.X,0,look.Z); if flatLook.Magnitude<.05 then flatLook=Vector3.new(0,0,-1) end; flatLook=flatLook.Unit
    -- v3.8.4.2 RECOVERY_ESCAPE: leave the boss's melee/AoE radius instead of only climbing above it.
    if Brain.forceEvade and Brain.emergency384 then
        if not M.escapeDir then
            local root=liveRoot(); local away=root and Vector3.new(root.Position.X-tp.X,0,root.Position.Z-tp.Z) or Vector3.zero
            if away.Magnitude<1 then away=-flatLook end
            M.escapeDir=away.Unit; M.escapeAngle=0; M.recoveryStartedAt=now
            RAVYN.Logger:log("WARN","RECOVERY_STARTED · escaping",{})
        end
        M.escapeAngle=M.escapeAngle+c.RecoveryStrafeSpeed*dt -- slow strafe along the escape radius
        local ca,sa=math.cos(M.escapeAngle),math.sin(M.escapeAngle)
        local d=M.escapeDir; local dir=Vector3.new(d.X*ca-d.Z*sa,0,d.X*sa+d.Z*ca)
        return tp+dir*c.RecoveryDistance+Vector3.new(0,c.RecoveryHeight,0),tp,true
    end
    if M.escapeDir then M.escapeDir=nil; M.recoveredAt=now end
    local h=c.FlyHeight
    if Brain.forceEvade then h=profile.above or h*3 end
    if c.HoverMode=="ABOVE" then return tp+Vector3.new(0,h,0),tp end
    if c.HoverMode=="ORBIT_HOVER" then
        M.orbitAngle=(M.orbitAngle+(c.OrbitSpeed*dt))%(math.pi*2)
        local rad=tonumber(c.HoverDistance) or c.OrbitRadius
        return tp+Vector3.new(math.cos(M.orbitAngle)*rad,h,math.sin(M.orbitAngle)*rad),tp
    end
    local behind=tonumber(c.HoverDistance) or c.FlyBehindOffset
    return tp-flatLook*behind+Vector3.new(0,h,0),tp
end
local lastFlight=os.clock()
local function flightStep()
    local now=os.clock(); local dt=math.clamp(now-lastFlight,0,.1); lastFlight=now
    if not hoverAllowed() then
        if M.flightActive then destroyMover() end
        M.escapeDir=nil
        local o=owner(); M.hoverState=(o=="DEFENSE" and "DEFENSE OVERRIDE") or (o=="TRAVEL" and "ACQUIRING TARGET") or "STANDBY"
        return
    end
    local root=liveRoot(); local target=LiveAction.target
    local desired,tp,escaping=hoverPoint(target,now,dt)
    if not root or not desired then destroyMover(); M.hoverState="STANDBY"; return end
    ensureMover(root); pcall(cancelTween)
    local c=cfg(); local here=root.Position
    -- feed-forward target velocity so a running target is followed smoothly, plus P-control to the point
    local tv=Vector3.zero
    local tr=rawTargetRoot and rawTargetRoot(target)
    if tr then local ok,v=pcall(function() return tr.AssemblyLinearVelocity end); if ok and v then tv=v end end
    local err=desired-here
    local v=tv+err*c.PositionGain
    local hv=Vector3.new(v.X,0,v.Z); if hv.Magnitude>c.FlySpeed then hv=hv.Unit*c.FlySpeed end
    local vy=clamp(v.Y,-c.VerticalSpeed,c.VerticalSpeed)
    M.bodyVelocity.Velocity=Vector3.new(hv.X,vy,hv.Z)
    local look=Vector3.new(tp.X,here.Y,tp.Z); if (look-here).Magnitude>.1 then M.bodyGyro.CFrame=CFrame.lookAt(here,look) end
    M.flightActive=true
    local locked=err.Magnitude<=2.2
    if escaping then
        M.recoveryState=(err.Magnitude>6) and "RECOVERY · ESCAPING" or "RECOVERY · SAFE HOLD"
        M.hoverState=M.recoveryState
    else
        M.recoveryState=(M.recoveredAt and now-M.recoveredAt<2.5) and "RECOVERED · RESUMING" or "STANDBY"
        M.hoverState=(locked and "LOCKED · "..c.HoverMode) or "FOLLOWING"
    end
    LiveAction.positionMode=M.hoverState
end

-- ---------------- control mitigation (separate detectors, all best-effort client side) ----------------
local badStates={[Enum.HumanoidStateType.FallingDown]=true,[Enum.HumanoidStateType.Ragdoll]=true,[Enum.HumanoidStateType.Physics]=true,[Enum.HumanoidStateType.PlatformStanding]=true}
local function suspicious(n)
    n=string.lower(tostring(n or ""))
    return string.find(n,"stun",1,true) or string.find(n,"knockdown",1,true) or string.find(n,"dazed",1,true) or string.find(n,"incapac",1,true)
end
local function mitigate(now)
    local c=cfg(); local hum=liveHumanoid(); local root=liveRoot(); if not hum then return end
    if c.NoRagdoll then
        local changed=false
        -- v3.8.4.1: Combat Hover uses BodyVelocity/BodyGyro only and never needs PlatformStand,
        -- so PlatformStand recovery also runs during hover.
        pcall(function() if hum.PlatformStand then hum.PlatformStand=false; changed=true end end)
        local ok,st=pcall(function() return hum:GetState() end)
        if ok and badStates[st] then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            task.defer(function() pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end) end)
            changed=true
        end
        if changed then M.mitigation.ragdoll=M.mitigation.ragdoll+1; M.recoveries=M.recoveries+1; M.lastAction="RAGDOLL RECOVER" end
    end
    if c.NoKnockback and root and not M.flightActive and owner()~="TRAVEL" and owner()~="DEFENSE" then
        local ok,v=pcall(function() return root.AssemblyLinearVelocity end)
        if ok and v and Vector3.new(v.X,0,v.Z).Magnitude>85 then
            pcall(function() root.AssemblyLinearVelocity=Vector3.new(0,math.min(v.Y,0),0) end)
            M.mitigation.knockback=M.mitigation.knockback+1; M.lastAction="KNOCKBACK DAMPED"
        end
    end
    if c.NoStun and now-M.lastStunSweep>=.12 then
        M.lastStunSweep=now
        local char=hum.Parent; local changed=false
        if char then
            local ok,desc=pcall(function() return char:GetDescendants() end)
            if ok then
                for i,v in ipairs(desc) do
                    if i>350 then break end
                    if suspicious(v.Name) then
                        if v:IsA("BoolValue") and v.Value then pcall(function() v.Value=false end); changed=true
                        elseif (v:IsA("NumberValue") or v:IsA("IntValue")) and (tonumber(v.Value) or 0)>0 then pcall(function() v.Value=0 end); changed=true end
                    end
                end
            end
            for _,obj in ipairs({char,hum}) do
                local ok2,attrs=pcall(function() return obj:GetAttributes() end)
                if ok2 then for k,val in pairs(attrs) do if suspicious(k) then
                    if val==true then pcall(function() obj:SetAttribute(k,false) end); changed=true
                    elseif type(val)=="number" and val>0 then pcall(function() obj:SetAttribute(k,0) end); changed=true end
                end end end
            end
        end
        if changed then M.mitigation.stun=M.mitigation.stun+1; M.lastAction="STUN CLEARED (MAY REAPPLY)" end
    end
    -- NoAttackSlowdown: no local reversible slowdown source has been observed; nothing is modified.
    M.mitigation.slowdown=c.NoAttackSlowdown and "NO_OBSERVED_SOURCE" or "OFF"
end

-- ---------------- single combat executor (v3.8.4.2: verified skills + input arbiter) ----------------
local faceCurrentTarget=CTX["faceCurrentTarget"]
local function defenseActive(now)
    local E=RAVYN.CombatEvolution
    return E and ((E.dodgeUntil or 0)>now or E.guardDown==true)
end
local SK={}; M.skill=SK
M.skillVerified=0; M.skillKeys={}; M.keySources=""; M.keysAt=-math.huge; M.everHadKeys=false
M.pending=nil; M.cdWatch={}; M.inputLockUntil=0; M.combatState="IDLE"; M.nextAction="—"; M.lastNoKeyAt=-math.huge
local function stat(k)
    local s=SK[k]
    if not s then s={attempts=0,sent=0,verified=0,unverified=0,consecFail=0,backoffUntil=0,lastSentAt=-math.huge,lastVerifiedAt=nil,lastFail=nil,
        cooldown=nil,cdSamples=0,dmg=0,dmgSamples=0,minRange=nil,maxRange=nil,lastEvidence=nil}; SK[k]=s end
    return s
end
local function refreshKeys(now)
    if now-M.keysAt<.5 then return M.skillKeys end
    M.keysAt=now
    local ok,keys=pcall(currentSkillKeys); keys=ok and keys or {}
    M.skillKeys=keys; M.skillsDiscovered=#keys
    local parts={}; for _,k in ipairs(keys) do table.insert(parts,k.key..":"..tostring(k.source)) end
    M.keySources=table.concat(parts," ")
    if #keys>0 then M.everHadKeys=true end
    return keys
end
-- GUI evidence: signature of the slot under the verified hotbar path (KeyLabel text excluded)
local function slotInstance(index)
    local p=game:GetService("Players").LocalPlayer; local pg=p and p:FindFirstChildOfClass("PlayerGui"); if not pg then return nil end
    local a=pg:FindFirstChild("ComponentsHolder"); a=a and a:FindFirstChild("BottomHolder"); a=a and a:FindFirstChild("SkillsHolder")
    return a and a:FindFirstChild(tostring(index).."-Skill") or nil
end
local function slotSignature(index)
    local slot=slotInstance(index); if not slot then return nil end
    local out={}
    local ok,desc=pcall(function() return slot:GetDescendants() end); if not ok then return nil end
    for i,d in ipairs(desc) do
        if i>80 then break end
        if d:IsA("GuiObject") and d.Name~="KeyLabel" then
            local s=d.Name..(d.Visible and "1" or "0")..string.format("%.2f,%.2f",d.Size.X.Scale,d.Size.Y.Scale)..string.format("%.2f",d.BackgroundTransparency)
            if d:IsA("ImageLabel") or d:IsA("ImageButton") then s=s..string.format("i%.2f",d.ImageTransparency) end
            if d:IsA("TextLabel") or d:IsA("TextButton") then s=s.."t"..string.sub(d.Text,1,12) end
            table.insert(out,s)
        end
    end
    return table.concat(out,"|")
end
local function animSet()
    local hum=liveHumanoid(); local set={}
    if not hum then return set end
    local an=hum:FindFirstChildOfClass("Animator")
    local ok,tracks=pcall(function() return an and an:GetPlayingAnimationTracks() or {} end)
    if ok then for _,t in ipairs(tracks) do local id=t.Animation and t.Animation.AnimationId or tostring(t); set[id]=true end end
    return set
end
local function readiness(k,now)
    local s=SK[k]; if not s then return "LEARNING" end
    if s.backoffUntil>now then return "BACKOFF" end
    if M.pending and M.pending.key==k then return "CASTING" end
    if M.cdWatch[k] then return "COOLDOWN" end
    if s.cooldown and s.lastVerifiedAt and now-s.lastVerifiedAt<s.cooldown*.95 then return "COOLDOWN" end
    if not s.cooldown and now-s.lastSentAt<cfg().ConservativeRetry then return "COOLDOWN_LEARNING" end
    return s.verified>0 and "READY" or "LEARNING"
end
M.readiness=readiness
local function pickSkill(target,dist,now)
    local keys=M.skillKeys; local best,bestScore,why=nil,-math.huge,"NO_READY_SKILL"
    local pct=(target.health and target.maxHealth and target.maxHealth>0) and target.health/target.maxHealth*100 or 100
    local maxD=1; for _,k in ipairs(keys) do local s=SK[k.key]; if s and s.dmg>maxD then maxD=s.dmg end end
    for _,k in ipairs(keys) do
        local r=readiness(k.key,now); local s=stat(k.key)
        local usable=(r=="READY" or r=="LEARNING")
        if usable and s.maxRange and dist>s.maxRange+5 then usable=false; why="OUT_OF_LEARNED_RANGE" end
        if usable then
            local rate=s.sent>0 and s.verified/s.sent or .5
            local score=rate*40+(s.dmg/maxD)*35+math.min(10,(now-s.lastSentAt)/2)
            if s.verified<3 then score=score+12 end
            if pct<=25 then score=score+rate*20 end
            if score>bestScore then best,bestScore=k,score end
        end
    end
    return best,why
end
-- v1.2.2: bus rejections that are transient (the previous action is still resolving) vs. ones that describe a capability
local TRANSIENT={ACTION_LOCK=true,COOLDOWN=true,PREVIOUS_ACTION_RUNNING=true,DEFENSE_ACTIVE=true,GUARD_HELD=true}
M.TRANSIENT=TRANSIENT
local function sendSkill(k,target,dist,now)
    local s=stat(k.key)
    pcall(function() if faceCurrentTarget then faceCurrentTarget(target) end end)
    local sigBefore=slotSignature(k.index); local tracksBefore=animSet()
    -- the hotbar key is an identifier; the CombatActionBus resolves and executes (or refuses) the skill
    local B=RAVYN.CombatActionBus
    local r=B and B:RequestSkill(k,target,{source="CombatMobility"}) or result(false,"COMBAT_BUS_UNAVAILABLE")
    LiveAction.lastInputSource=(r.value and r.value.backend) or r.code
    if not r.ok then
        if TRANSIENT[r.code] then return false end
        s.attempts=s.attempts+1; M.skillAttempts=M.skillAttempts+1
        s.lastFail=tostring(r.code); M.skillFailReason=r.code
        s.backoffUntil=math.max(s.backoffUntil or 0,now+2) -- capability refusal: rest this key, M1 continues
        return false
    end
    s.attempts=s.attempts+1; M.skillAttempts=M.skillAttempts+1
    M.lastSkillBackend=r.value and r.value.backend
    s.sent=s.sent+1; s.lastSentAt=now; M.skillSent=M.skillSent+1; M.skillCount=M.skillSent
    M.lastSkillKey=k.key; M.lastSkillAt=now; M.skillFailReason="INPUT_SENT"; M.comboStage=0
    M.inputLockUntil=now+cfg().SkillCastLock
    M.pending={key=k.key,index=k.index,at=now,sigBefore=sigBefore,tracksBefore=tracksBefore,targetId=target.id,hpBefore=target.health,maxHealth=target.maxHealth,dist=dist,nextPoll=now+.1}
    LiveAction.lastSkill=now
    Brain.combo.lastSkillKey=k.key; Brain.combo.lastSkillAt=Brain.combo.lastSkillAt or {}; Brain.combo.lastSkillAt[k.key]=now; Brain.combo.m1=0; Brain.combo.lastAction="SKILL "..k.key
    local E=RAVYN.CombatEvolution
    if E then
        E.skillUseCount=(E.skillUseCount or 0)+1
        E.pendingSkill={key=k.key,targetId=target.id,hpBefore=target.health,maxHealth=target.maxHealth,at=now}
    end
    M.lastAction="SKILL "..k.key.." · SENT"
    RAVYN.Logger:log("INFO","SMART_SKILL_"..k.key,{target=target.name,source=k.source})
    return true
end
-- verification: GUI state change, new animation track, or target HP drop inside the cast lock
local function verifyStep(now)
    local p=M.pending; if not p or now<p.nextPoll then return end
    p.nextPoll=now+.1
    local s=stat(p.key); local evidence=nil
    local sig=slotSignature(p.index)
    if p.sigBefore and sig and sig~=p.sigBefore then evidence="GUI_STATE" end
    if not evidence then local after=animSet(); for id in pairs(after) do if not p.tracksBefore[id] then evidence="ANIMATION"; break end end end
    local t=LiveAction.target
    local dmg=(t and t.id==p.targetId and p.hpBefore and t.health) and (p.hpBefore-t.health) or 0
    if not evidence and dmg>0 and now-p.at<=cfg().SkillCastLock+.3 then evidence="TARGET_HP" end
    if evidence then
        s.verified=s.verified+1; s.consecFail=0; s.lastVerifiedAt=p.at; s.lastFail=nil; s.lastEvidence=evidence
        if s.verified==1 then RAVYN.Logger:log("INFO","SKILL_VERIFIED_"..p.key.." · "..evidence,{}) end -- first verification per key only
        M.skillVerified=M.skillVerified+1; M.skillFailReason="OK"; M.lastAction="SKILL "..p.key.." · VERIFIED"
        s.minRange=math.min(s.minRange or p.dist,p.dist); s.maxRange=math.max(s.maxRange or p.dist,p.dist)
        if dmg>0 then s.dmg=s.dmgSamples==0 and dmg or (s.dmg*.7+dmg*.3); s.dmgSamples=s.dmgSamples+1 end
        if p.sigBefore and evidence=="GUI_STATE" then M.cdWatch[p.key]={start=p.at,ready=p.sigBefore,index=p.index,nextPoll=now+.25} end
        M.pending=nil
    elseif now-p.at>1.4 then
        s.unverified=s.unverified+1; s.consecFail=s.consecFail+1; s.lastFail="SKILL_INPUT_SENT_UNVERIFIED"
        M.skillFailReason="SKILL_INPUT_SENT_UNVERIFIED"; M.lastAction="SKILL "..p.key.." · UNVERIFIED"
        if s.consecFail>=3 then s.backoffUntil=now+cfg().SkillBackoff; s.lastFail="SKILL_BACKOFF"; M.skillFailReason="SKILL_BACKOFF" end
        M.pending=nil
    end
end
-- cooldown learning: time until the slot GUI returns to its pre-cast signature
local function cooldownStep(now)
    for key,w in pairs(M.cdWatch) do
        if now>=w.nextPoll then
            w.nextPoll=now+.25
            local sig=slotSignature(w.index)
            if sig==w.ready then
                local s=stat(key); local cd=math.clamp(now-w.start,.3,60)
                s.cooldown=s.cdSamples==0 and cd or (s.cooldown*.6+cd*.4); s.cdSamples=s.cdSamples+1
                M.cdWatch[key]=nil
            elseif now-w.start>60 or not sig then M.cdWatch[key]=nil end
        end
    end
end
M.cooldownStep=cooldownStep

local function combatStep(now)
    local c=cfg(); local target=LiveAction.target
    verifyStep(now)
    if not target or not c.Enabled or not RAVYN.FSM or RAVYN.FSM.state~="RUNNING" then M.combatState="IDLE"; M.nextAction="—"; return end
    -- InstaKillAdapter (Threshold 99): while a finisher is armed or being verified, normal combat sends nothing (the bus refuses it too)
    local IKA=RAVYN.InstaKillAdapter
    -- checked before EVERY attack decision, so a target sitting at ≤1% is never hit by a normal action first
    if IKA and (IKA.locked or (IKA.preAttack and IKA.preAttack(target,now))) then
        M.combatState="FINISHER"; M.nextAction=(IKA.session and IKA.session.phase=="VERIFY") and "VERIFY KILL" or "FINISHER ARMED"; M.skillFailReason="FINISHER_LOCK"
        return
    end
    local o=owner()
    if Brain.forceEvade and Brain.emergency384 then M.combatState="RECOVERY"; M.nextAction="ESCAPE"; M.skillFailReason="EMERGENCY · COMBAT PAUSED"; return end
    if defenseActive(now) then M.combatState="DEFENSE_INTERRUPT"; M.nextAction="DEFENSE"; M.skillFailReason="DEFENSE_ACTIVE"; return end
    if o=="TRAVEL" then M.combatState="APPROACH"; M.nextAction="TRAVEL"; return end
    local root=liveRoot(); local tp=targetBasis(target); if not root or not tp then return end
    local profile=Hooks.activeProfile(); local dist=(root.Position-tp).Magnitude
    local m1Range=math.max((profile.attackDistance or 9)+1.5,12)
    local skillRange=math.max((profile.attackDistance or 9)+10,18)
    if M.pending and now<M.inputLockUntil then M.combatState="SKILL_CAST"; M.nextAction="WAIT CAST"; return end
    local pct=(target.health and target.maxHealth and target.maxHealth>0) and target.health/target.maxHealth*100 or 100
    -- skills
    local pp=params()
    local atDecision=(not c.HoldCombo) or M.comboStage>=pp.combo or not RAVYN.Config.Combat.AutoAttack
    local nextSkill=nil
    if RAVYN.Config.Combat.AutoAbilities then
        local keys=refreshKeys(now)
        if #keys==0 then
            M.nextAction="M1"
            if now-M.lastNoKeyAt>=1.5 then
                M.lastNoKeyAt=now; M.skillAttempts=M.skillAttempts+1
                M.skillFailReason=M.everHadKeys and "SKILL_HOTBAR_NOT_READY" or "HOTBAR_KEYS_UNRESOLVED"
            end
        elseif not M.pending and now-(LiveAction.lastSkill or 0)>=pp.skill then
            local k,why=pickSkill(target,dist,now); nextSkill=k
            if k and atDecision and dist<=math.max(skillRange,(stat(k.key).maxRange or 0)+2) then
                if sendSkill(k,target,dist,now) then M.combatState=(pct<=25) and "FINISHER" or "SKILL_CAST"; M.nextAction="VERIFY "..k.key; return end
            elseif not k then M.skillFailReason=why end
        end
    end
    M.nextAction=(nextSkill and atDecision) and ("SKILL "..nextSkill.key) or "M1"
    -- M1 (blocked while a skill cast lock is active)
    -- Adaptive M1: fast, but only as fast as useful. Damage evidence = target HP dropping.
    if target.id~=M.hpTargetId then M.hpTargetId=target.id; M.hpLast=target.health; M.lastDamageAt=now; M.inRangeSince=nil end
    if target.health and M.hpLast and target.health<M.hpLast then M.lastDamageAt=now end
    M.hpLast=target.health
    local interval=pp.m1
    if dist<=m1Range then
        M.inRangeSince=M.inRangeSince or now
        if now-M.inRangeSince>2 and now-(M.lastDamageAt or now)>2 then interval=pp.m1*1.6; M.m1Adaptive="NOT_LANDING · SLOWED" else M.m1Adaptive="LANDING" end
    else M.inRangeSince=nil; M.m1Adaptive="OUT_OF_RANGE" end
    M.m1Interval=interval
    if RAVYN.Config.Combat.AutoAttack and dist<=m1Range and now>=M.inputLockUntil and now-(LiveAction.lastAttack or 0)>=interval then
        local ok,r=pcall(function() return RAVYN:ClientAttack() end)
        if ok and r and r.ok then
            M.m1Attempts=M.m1Attempts+1
            LiveAction.lastAttack=now; Brain.combo.m1=(Brain.combo.m1 or 0)+1; Brain.combo.lastAction="M1"
            M.m1Sent=M.m1Sent+1; M.m1Count=M.m1Sent; M.comboStage=M.comboStage+1; M.m1Blocked=nil
            M.lastAction=string.format("M1 ×%d",M.comboStage); M.combatState=(pct<=25) and "FINISHER" or "M1_CHAIN"
            if M.comboStage>pp.combo*3 then M.comboStage=pp.combo end
        elseif ok and r and not TRANSIENT[r.code] then
            -- refused (e.g. SILENT with no verified attack action): nothing was sent; retry at the normal cadence only
            M.m1Attempts=M.m1Attempts+1; LiveAction.lastAttack=now; M.m1Blocked=r.code; M.lastAction="M1 · "..tostring(r.code)
        end
    elseif dist>m1Range then M.combatState="HOVER_LOCK" end
end

local baseProfile=Hooks.activeProfile
Hooks.activeProfile=function()
    local p=baseProfile(); local c=cfg()
    if c.Enabled then local pp=params(); p.attackCooldown=math.min(p.attackCooldown or .4,pp.m1); p.skillDelay=math.min(p.skillDelay or 1,pp.skill) end
    return p
end

function RAVYN:GetCombatMobilityStatus()
    return result(true,"COMBAT_MOBILITY_STATUS",{hover=M.hoverState,flightActive=M.flightActive,owner=owner(),m1Sent=M.m1Sent,m1Attempts=M.m1Attempts,
        skillSent=M.skillSent,skillAttempts=M.skillAttempts,skillsDiscovered=M.skillsDiscovered,lastSkill=M.lastSkillKey,skillFailReason=M.skillFailReason,
        comboStage=M.comboStage,mitigation=M.mitigation,lastAction=M.lastAction})
end

M.token=M.token+1
local token=M.token
task.spawn(function()
    while not RAVYN._destroyed and M.token==token do
        local now=os.clock()
        M.executorOwns=cfg().Enabled==true
        local ok,err=pcall(flightStep); if not ok then RAVYN.Logger:log("ERROR","HOVER_STEP",{error=tostring(err)}) end
        pcall(mitigate,now)
        local ok2,err2=pcall(combatStep,now); if not ok2 then RAVYN.Logger:log("ERROR","COMBAT_STEP",{error=tostring(err2)}) end
        pcall(cooldownStep,now)
        if not LiveAction.target then M.comboStage=0 end
        task.wait(.03)
    end
    M.executorOwns=false
    destroyMover()
end)

local oldStop=RAVYN.Stop
function RAVYN:Stop()
    destroyMover(); M.comboStage=0; M.hoverState="RELEASED"
    local hum=liveHumanoid(); if hum then pcall(function() hum.PlatformStand=false end) end
    return oldStop(self)
end
local oldDestroy=RAVYN.Destroy
function RAVYN:Destroy() M.token=M.token+1; destroyMover(); return oldDestroy(self) end
CTX["CM384"]=M
print("RAVYN v3.8.4 COMBAT HOVER | OWNERSHIP-GATED | HOLD COMBO | SPLIT MITIGATION")
return true]==========]); if not ok then return end end
do local ok=runChunk("ProbeFrameworkV385.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local liveRoot=CTX["liveRoot"]
-- v3.8.5 LEARN ACTION probe framework (evidence capture only — never marks anything VERIFIED).
-- BEFORE snapshot → the user performs the action manually once → AFTER snapshot → diff → ActionEvidence.
-- While recording: ProximityPromptService.PromptTriggered, GuiButton.Activated and key/mouse input are logged.
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local PPS=game:GetService("ProximityPromptService")
local LP=Players.LocalPlayer
local PR={recording=nil,records={},presets={},lastReport=nil,captures=0}
RAVYN.Probe=PR
-- presets = labels + the game system they document (GameKnowledge counts evidence per system)
PR.presets={
    {"Crow · equip","CROW_MISSION"},{"Crow · open missions","CROW_MISSION"},{"Crow · select mission","CROW_MISSION"},{"Crow · accept","CROW_MISSION"},
    {"Crow · progress","CROW_MISSION"},{"Crow · complete/turn in","CROW_MISSION"},
    {"Muzan · task menu","MUZAN_HUNT"},{"Muzan · accept hunt","MUZAN_HUNT"},{"Muzan · transformation step","MUZAN_TRANSFORMATION"},
    {"Quest · accept","NORMAL_QUEST"},{"Quest · progress","NORMAL_QUEST"},{"Quest · turn in","NORMAL_QUEST"},
    {"Training · start station","BREATHING_TRAINING"},{"Training · minigame","BREATHING_TRAINING"},{"Trainer · accept","BREATHING_TRAINING"},
    {"Dungeon · queue/ready","OUWIGAHARA"},{"Dungeon · card pick","OUWIGAHARA"},{"Final Selection · step","FINAL_SELECTION"},
    {"Shop · purchase","SHOP"},{"Chest · open","BOSS_HUNT"},{"Custom action","OTHER"},
}
local function exec(name) local f=(getgenv and getgenv()[name]) or G[name]; return type(f)=="function" and f or nil end
local function vis(g,stopAt)
    local cur=g
    for _=1,20 do
        if not cur or cur==stopAt then return true end
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("LayerCollector") and not cur.Enabled then return false end
        cur=cur.Parent
    end
    return true
end
local function short(s,n) s=tostring(s or ""); s=string.gsub(s,"[\r\n]+"," "); return #s>(n or 80) and (string.sub(s,1,n or 80).."…") or s end

-- ---------- GUI snapshot (RAVYN's own ScreenGui excluded) ----------
local function guiSnapshot()
    local out={}; local n=0
    local pg=LP and LP:FindFirstChildOfClass("PlayerGui"); if not pg then return out,0 end
    local ok,desc=pcall(function() return pg:GetDescendants() end); if not ok then return out,0 end
    local own=RAVYN._gui
    for _,d in ipairs(desc) do
        if n>=4000 then break end
        if not (own and (d==own or d:IsDescendantOf(own))) then
            local isText=d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")
            local isBtn=d:IsA("GuiButton")
            local isGui=d:IsA("LayerCollector")
            local shallowFrame=d:IsA("GuiObject") and d.Parent and d.Parent:IsA("LayerCollector")
            if isText or isBtn or isGui or shallowFrame then
                n=n+1
                out[d:GetFullName()]={t=isText and short(d.Text,100) or nil,v=vis(d,pg),k=(isGui and "GUI") or (isBtn and "BTN") or (isText and "TXT") or "FRM",
                    name=d.Name,class=d.ClassName}
            end
        end
    end
    return out,n
end
-- ---------- world snapshot near the player ----------
local function holderOf(p)
    local m=p:FindFirstAncestorWhichIsA("Model")
    if m and m~=workspace then local ok,s=pcall(function() return m:GetExtentsSize() end); if ok and s.Magnitude<=80 then return m end end
    return p
end
local function worldSnapshot(radius)
    local out={holders={},prompts={},top={},markers={}}
    local root=liveRoot()
    for _,c in ipairs(workspace:GetChildren()) do out.top[c:GetFullName()]=c.ClassName end
    if not root then return out end
    local params=OverlapParams.new(); if root.Parent then params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={root.Parent} end
    local ok,parts=pcall(function() return workspace:GetPartBoundsInRadius(root.Position,radius,params) end)
    if ok then
        local seen={}
        for i,p in ipairs(parts) do
            if i>1500 then break end
            local h=holderOf(p)
            if not seen[h] then
                seen[h]=true
                local d=root.Position
                if h:IsA("BasePart") then d=h.Position else local okP,cf=pcall(function() return h:GetPivot() end); if okP then d=cf.Position end end
                out.holders[h:GetFullName()]={class=h.ClassName,dist=(d-root.Position).Magnitude}
                local okD,desc=pcall(function() return h:GetDescendants() end)
                if okD then
                    for j,x in ipairs(desc) do
                        if j>120 then break end
                        if x:IsA("ProximityPrompt") then out.prompts[x:GetFullName()]={a=x.ActionText,o=x.ObjectText,e=x.Enabled,h=x.HoldDuration,m=x.MaxActivationDistance}
                        elseif x:IsA("ClickDetector") then out.prompts[x:GetFullName()]={a="(ClickDetector)",o="",e=true,h=0,m=x.MaxActivationDistance}
                        elseif x:IsA("BillboardGui") then
                            local txt={}; for _,y in ipairs(x:GetDescendants()) do if (y:IsA("TextLabel") or y:IsA("TextButton")) and y.Text~="" then table.insert(txt,short(y.Text,40)) end end
                            out.markers[x:GetFullName()]=table.concat(txt," | ")
                        end
                    end
                end
            end
        end
    end
    return out
end
-- ---------- player state (verified reads + raw candidates, never interpreted here) ----------
local function playerSnapshot()
    local out={attrs={},values={},tools={},equipped=nil,level=nil,xp=nil}
    if not LP then return out end
    for k,v in pairs(LP:GetAttributes()) do out.attrs["Player@"..k]=tostring(v) end
    local char=RAVYN.ReadAdapter and RAVYN.ReadAdapter:getCharacter(); char=char and char.ok and char.value or LP.Character
    if char then
        for k,v in pairs(char:GetAttributes()) do out.attrs["Character@"..k]=tostring(v) end
        local tool=char:FindFirstChildOfClass("Tool"); out.equipped=tool and tool.Name or nil
    end
    local bp=LP:FindFirstChildOfClass("Backpack")
    if bp then for _,t in ipairs(bp:GetChildren()) do table.insert(out.tools,t.Name) end; table.sort(out.tools) end -- GetChildren order is not semantic
    local ok,desc=pcall(function() return LP:GetDescendants() end)
    if ok then
        local n=0
        for _,d in ipairs(desc) do
            if d:IsA("ValueBase") and not d:FindFirstAncestorOfClass("PlayerGui") and not d:FindFirstAncestorOfClass("PlayerScripts") then
                n=n+1; if n>400 then break end
                local okV,v=pcall(function() return d.Value end)
                out.values[d:GetFullName()]=okV and short(tostring(v),60) or "?"
            end
        end
    end
    local RA=RAVYN.ReadAdapter
    if RA then
        local l=RA:getLevel(); if l and l.ok then out.level=l.value end
        local x=RA:getXP(); if x and x.ok then out.xp=x.value end
    end
    return out
end
-- global marker snapshot: BillboardGui / Highlight / Beam anywhere, with WORLD position (never screen/minimap)
local function markerWorldPos(inst)
    local a=inst:IsA("BillboardGui") and (inst.Adornee or inst.Parent) or (inst:IsA("Highlight") and (inst.Adornee or inst.Parent)) or nil
    if inst:IsA("Beam") then local at=inst.Attachment1 or inst.Attachment0; return at and at.WorldPosition or nil,at end
    if a and a:IsA("BasePart") then return a.Position,a end
    if a and a:IsA("Attachment") then return a.WorldPosition,a end
    if a and a:IsA("Model") then local ok,cf=pcall(function() return a:GetPivot() end); if ok then return cf.Position,a end end
    return nil,a
end
local function globalMarkers()
    local out={}; local n=0; local own=RAVYN._gui
    local function take(d)
        if n>=250 then return end
        if not (d:IsA("BillboardGui") or d:IsA("Highlight") or d:IsA("Beam")) then return end
        if own and d:IsDescendantOf(own) then return end
        local pos,ad=markerWorldPos(d)
        local txt={}
        if d:IsA("BillboardGui") then for _,y in ipairs(d:GetDescendants()) do if (y:IsA("TextLabel") or y:IsA("TextButton")) and y.Text~="" then table.insert(txt,short(y.Text,30)) end end end
        n=n+1
        out[d:GetFullName()]=d.ClassName..(pos and string.format(" @(%.0f,%.0f,%.0f)",pos.X,pos.Y,pos.Z) or " @(no world pos)")
            ..(ad and (" adornee "..ad:GetFullName()) or "")..(#txt>0 and (" '"..table.concat(txt," | ").."'") or "")
    end
    local pg=LP and LP:FindFirstChildOfClass("PlayerGui")
    if pg then for _,d in ipairs(pg:GetDescendants()) do take(d) end end
    local ok,desc=pcall(function() return workspace:GetDescendants() end)
    if ok then for i,d in ipairs(desc) do if i>25000 then break end; take(d) end end
    return out
end
PR.guiSnapshot=guiSnapshot; PR.worldSnapshot=worldSnapshot; PR.playerSnapshot=playerSnapshot; PR.globalMarkers=globalMarkers

-- ---------- diff ----------
local function diffMaps(a,b,fmt)
    local added,removed,changed={},{},{}
    for k,v in pairs(b) do
        local o=a[k]
        if o==nil then table.insert(added,fmt(k,v,nil))
        elseif fmt(k,v,nil)~=fmt(k,o,nil) then table.insert(changed,fmt(k,o,nil).."  →  "..fmt(k,v,nil)) end
    end
    for k,v in pairs(a) do if b[k]==nil then table.insert(removed,fmt(k,v,nil)) end end
    table.sort(added); table.sort(removed); table.sort(changed)
    return added,removed,changed
end
local function guiFmt(k,v) return k.." ["..v.k..(v.v and "" or " hidden").."]"..(v.t and (" = "..v.t) or "") end
local function kvFmt(k,v) return k.." = "..tostring(v) end
local function promptFmt(k,v) return k.." ["..tostring(v.a).."|"..tostring(v.o).."|en="..tostring(v.e).."|hold="..tostring(v.h).."]" end
local function holderFmt(k,v) return k.." ("..v.class..string.format(", %.0f studs)",v.dist) end
local function push(lines,title,list,limit)
    if #list==0 then return end
    table.insert(lines,title.." ("..#list..")")
    for i,x in ipairs(list) do if i>(limit or 20) then table.insert(lines,"   … "..(#list-(limit or 20)).." more"); break end; table.insert(lines,"   "..x) end
end

-- ---------- recording ----------
local function stopHooks(rec)
    for _,c in ipairs(rec.conns) do pcall(function() c:Disconnect() end) end
    rec.conns={}
end
local function startHooks(rec)
    rec.conns={}; rec.events={}
    local function ev(s) if #rec.events<80 then table.insert(rec.events,string.format("+%.2fs %s",os.clock()-rec.at,s)) end end
    table.insert(rec.conns,PPS.PromptTriggered:Connect(function(prompt,player)
        if player==LP then
            rec.triggered=rec.triggered or {}
            table.insert(rec.triggered,{path=prompt:GetFullName(),a=prompt.ActionText,o=prompt.ObjectText,hold=prompt.HoldDuration})
            ev("PROMPT_TRIGGERED "..prompt:GetFullName().." ["..prompt.ActionText.."|"..prompt.ObjectText.."]")
        end
    end))
    table.insert(rec.conns,UIS.InputBegan:Connect(function(input,gp)
        if input.UserInputType==Enum.UserInputType.Keyboard then ev("KEY "..input.KeyCode.Name..(gp and " (gui)" or ""))
        elseif input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            ev(string.format("CLICK (%.0f,%.0f)%s",input.Position.X,input.Position.Y,gp and " (gui)" or "")) end
    end))
    local pg=LP and LP:FindFirstChildOfClass("PlayerGui")
    if pg then
        local own=RAVYN._gui
        rec.hooked={}; rec.hookCount=0
        local function hook(d)
            if rec.hookCount>=1500 or rec.hooked[d] or not d:IsA("GuiButton") or (own and d:IsDescendantOf(own)) then return end
            rec.hooked[d]=true; rec.hookCount=rec.hookCount+1
            table.insert(rec.conns,d.Activated:Connect(function()
                rec.buttons=rec.buttons or {}
                local txt=d:IsA("TextButton") and d.Text or ""
                local lbl=d:FindFirstChildWhichIsA("TextLabel",true)
                table.insert(rec.buttons,{path=d:GetFullName(),text=short(txt~="" and txt or (lbl and lbl.Text) or "",60)})
                ev("BUTTON "..d:GetFullName().." '"..short(txt~="" and txt or (lbl and lbl.Text) or "",40).."'")
            end))
        end
        for _,d in ipairs(pg:GetDescendants()) do hook(d) end
        -- menus created after Start (e.g. a mission list) fire DescendantAdded for every nested descendant
        table.insert(rec.conns,pg.DescendantAdded:Connect(function(d)
            if not PR.recording or PR.recording~=rec then return end
            if d:IsA("GuiButton") then hook(d); ev("GUI ADDED "..d:GetFullName()) end
        end))
    end
end
function RAVYN:LearnActionBegin(label,system)
    if PR.recording then return result(false,"ALREADY_RECORDING") end
    local g,gn=guiSnapshot()
    PR.seq=(PR.seq or 0)+1
    PR.recording={label=tostring(label or "Custom action"),system=system or "OTHER",at=os.clock(),clock=os.date("%H:%M:%S"),seq=PR.seq,
        gui=g,guiCount=gn,world=worldSnapshot(80),markers=globalMarkers(),player=playerSnapshot(),conns={}}
    startHooks(PR.recording)
    RAVYN.Logger:log("INFO","LEARN_ACTION_BEGIN",{label=PR.recording.label})
    return result(true,"RECORDING",{label=PR.recording.label,guiNodes=gn})
end
function RAVYN:LearnActionEnd()
    local rec=PR.recording; if not rec then return result(false,"NOT_RECORDING") end
    PR.recording=nil; stopHooks(rec)
    local g2=guiSnapshot(); local w2=worldSnapshot(80); local p2=playerSnapshot()
    local lines={string.format("LEARN ACTION #%03d · %s · system %s · %s → %s · %.1fs",rec.seq,rec.label,rec.system,rec.clock,os.date("%H:%M:%S"),os.clock()-rec.at),
        "status: EVIDENCE ONLY (not verified)"}
    -- interaction candidate + confidence
    local cand,conf="NONE OBSERVED","LOW"
    local ga,gr,gc=diffMaps(rec.gui,g2,guiFmt)
    local stateChanged=(#ga+#gr+#gc)>0
    if rec.triggered and rec.triggered[1] then
        local t=rec.triggered[#rec.triggered]; cand="PROXIMITY_PROMPT "..t.path.." ["..t.a.."|"..t.o.."|hold="..t.hold.."]"; conf=stateChanged and "HIGH" or "MEDIUM"
    elseif rec.buttons and rec.buttons[1] then
        local b=rec.buttons[#rec.buttons]; cand="GUI_BUTTON "..b.path.." '"..b.text.."'"; conf=stateChanged and "MEDIUM" or "LOW"
    end
    table.insert(lines,"interaction candidate: "..cand.."  ·  confidence "..conf)
    push(lines,"input/events",rec.events or {},40)
    push(lines,"GUI added",ga,30); push(lines,"GUI removed",gr,30); push(lines,"GUI changed",gc,30)
    local wa,wr=diffMaps(rec.world.holders,w2.holders,holderFmt)
    push(lines,"world objects added (≤80 studs)",wa,20); push(lines,"world objects removed",wr,20)
    local pa,prm,pc=diffMaps(rec.world.prompts,w2.prompts,promptFmt)
    push(lines,"prompts added",pa,15); push(lines,"prompts removed",prm,15); push(lines,"prompts changed",pc,15)
    local ma,mr,mc=diffMaps(rec.world.markers,w2.markers,kvFmt)
    push(lines,"markers added",ma,10); push(lines,"markers removed",mr,10); push(lines,"markers changed",mc,10)
    local gma,gmr,gmc=diffMaps(rec.markers or {},globalMarkers(),kvFmt)
    push(lines,"global markers added (world pos)",gma,15); push(lines,"global markers removed",gmr,15); push(lines,"global markers changed",gmc,15)
    local ta,tr=diffMaps(rec.world.top,w2.top,kvFmt)
    push(lines,"workspace children added",ta,10); push(lines,"workspace children removed",tr,10)
    local aa,ar,ac=diffMaps(rec.player.attrs,p2.attrs,kvFmt)
    push(lines,"player attributes added",aa,15); push(lines,"player attributes removed",ar,15); push(lines,"player attributes changed",ac,15)
    local va,vr,vc=diffMaps(rec.player.values,p2.values,kvFmt)
    push(lines,"player values added",va,15); push(lines,"player values removed",vr,15); push(lines,"player values changed",vc,20)
    if tostring(rec.player.equipped)~=tostring(p2.equipped) then table.insert(lines,"equipped tool: "..tostring(rec.player.equipped).." → "..tostring(p2.equipped)) end
    if table.concat(rec.player.tools,",")~=table.concat(p2.tools,",") then table.insert(lines,"backpack: ["..table.concat(rec.player.tools,", ").."] → ["..table.concat(p2.tools,", ").."]") end
    if tostring(rec.player.level)~=tostring(p2.level) or tostring(rec.player.xp)~=tostring(p2.xp) then
        table.insert(lines,"level/xp: "..tostring(rec.player.level).."/"..tostring(rec.player.xp).." → "..tostring(p2.level).."/"..tostring(p2.xp)) end
    local text=table.concat(lines,"\n")
    local evidence={actionName=rec.label,system=rec.system,at=os.clock(),clock=rec.clock,seq=rec.seq,interactionCandidate=cand,confidence=conf,
        guiChanges=#ga+#gr+#gc,worldChanges=#wa+#wr+#gma+#gmr+#gmc,valueChanges=#va+#vr+#vc,text=text}
    table.insert(PR.records,evidence); while #PR.records>12 do table.remove(PR.records,1) end
    PR.lastReport=text; PR.captures=PR.captures+1
    local GK=RAVYN.GameKnowledge; if GK and GK.recordEvidence then pcall(GK.recordEvidence,evidence) end
    local wf,mf,isf=exec("writefile"),exec("makefolder"),exec("isfolder")
    if wf then pcall(function()
        if mf and isf and not isf("RAVYN") then mf("RAVYN") end
        if mf and isf and not isf("RAVYN/Probes") then mf("RAVYN/Probes") end
        local safe=string.gsub(rec.label,"[^%w]+","_")
        wf("RAVYN/Probes/"..os.date("%Y%m%d_%H%M%S").."_"..string.format("%03d",rec.seq).."_"..safe..".txt",text)
        evidence.file=true
    end) end
    RAVYN.Logger:log("INFO","LEARN_ACTION_END",{label=rec.label,candidate=cand,confidence=conf})
    return result(true,"ACTION_EVIDENCE",evidence)
end
local function cancelRecording(reason)
    local rec=PR.recording; if not rec then return false end
    stopHooks(rec); PR.recording=nil
    PR.lastCancelled={label=rec.label,seq=rec.seq,reason=reason,at=os.clock()}
    RAVYN.Logger:log("INFO","LEARN_ACTION_CANCELLED",{label=rec.label,reason=reason})
    return true
end
function RAVYN:CancelLearnAction() cancelRecording("USER"); return result(true,"CANCELLED") end
function RAVYN:CopyLearnActionReport()
    local f=exec("setclipboard"); if not PR.lastReport then return result(false,"NO_ACTION_EVIDENCE") end
    if not f then return result(false,"SETCLIPBOARD_UNAVAILABLE") end
    pcall(f,PR.lastReport); return result(true,"ACTION_EVIDENCE_COPIED")
end
-- Stop Everything stops EVERYTHING temporary: an in-progress recording is cancelled and not saved
local baseStop=RAVYN.Stop
function RAVYN:Stop() cancelRecording("STOP"); return baseStop(self) end
local baseDestroy=RAVYN.Destroy
function RAVYN:Destroy() cancelRecording("DESTROY"); return baseDestroy(self) end
CTX["Probe385"]=PR
RAVYN.Logger:log("INFO","PROBE_FRAMEWORK_V385_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("GameKnowledgeV385.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local liveRoot=CTX["liveRoot"]
-- v3.8.5 GameKnowledge: one place for what RAVYN understands about Slayers 2 — and how sure it is.
-- Every fact carries its source: VERIFIED (live evidence) · REFERENCE (guides; never a binding) · UNRESOLVED.
local GK={systems={},order={},evidence={},progress={},world={state="UNKNOWN"},markers={},markersAt=-math.huge}
RAVYN.GameKnowledge=GK
local function sys(key,title,def) def.key=key; def.title=title; def.evidence=0; def.lastEvidence=nil; GK.systems[key]=def; table.insert(GK.order,key) end
-- research checklist (doc: entry · start · start verify · objectives · progress · failure · completion · next · paths · unknown)
sys("NORMAL_QUEST","Normal NPC quest",{status="PARTIAL",
    entry="REFERENCE: talk to quest NPC",start="VERIFIED: ProximityPrompt + dialogue (AdaptiveIntel fireproximityprompt path)",
    startVerify="PARTIAL: quest text signature change",objectives="UNRESOLVED: tracker semantics (QUEST_READ unresolved)",
    progress="PARTIAL: x/y counters in visible quest text",completion="PARTIAL: signature change after turn-in",
    paths="VERIFIED: PlayerGui.ComponentsHolder.LeftCenterFramesHolder.zQuestsFrame · QuestionStrip · Quest Exp Factor Holder",
    unknown="tracker tree semantics, objective types other than kill"})
sys("CROW_MISSION","Crow mission",{status="UNRESOLVED",
    entry="REFERENCE: after Final Selection; Crow obtained and equipped",start="UNRESOLVED: mission list / Crow interaction",
    startVerify="UNRESOLVED",objectives="UNRESOLVED",progress="UNRESOLVED",completion="UNRESOLVED",
    paths="none verified",unknown="how the Crow is summoned/equipped, mission list UI, selection, accept, turn-in",
    note="Current QuestBrain Crow flow assumes a world ProximityPrompt containing 'crow'. Record Crow presets to replace this assumption."})
sys("MUZAN_TRANSFORMATION","Muzan transformation (human → demon)",{status="UNRESOLVED",
    entry="REFERENCE: human + reputation requirement",start="REFERENCE: find Muzan → Biwa Bell → lair",
    objectives="REFERENCE: Spider Lilies (collect) · Dr. Higoshima (capture/carry/deliver) · Muzan's Blood",
    progress="UNRESOLVED",completion="REFERENCE: race becomes demon",paths="none verified",
    unknown="every binding; carry/deliver mechanics"})
sys("MUZAN_HUNT","Muzan demon tasks / hunts",{status="UNRESOLVED",
    entry="REFERENCE: demon, Muzan's Lair, 'Give me a task'",start="UNRESOLVED: task menu",objectives="REFERENCE: hunt targets (e.g. trainees)",
    progress="UNRESOLVED",completion="UNRESOLVED",paths="none verified",unknown="task list UI, selection, lock/cooldown states"})
sys("BREATHING_TRAINING","Breathing training",{status="UNRESOLVED",
    entry="REFERENCE: trainer + requirements",start="REFERENCE: stations use a 'Train' interaction",
    objectives="REFERENCE: sequential stages (e.g. Thunder: Meditation, Cup, Push Ups, Aim, Boulder Split, Trainee)",
    progress="REFERENCE: training quest 0/6",completion="UNRESOLVED: unlock evidence",paths="none verified",
    unknown="trainer dialogue, station prompts, every minigame GUI"})
sys("FINAL_SELECTION","Final Selection",{status="UNRESOLVED",
    entry="UNRESOLVED",start="UNRESOLVED",objectives="REFERENCE: collection, combat, parkour (timer/hearts/levers)",
    progress="UNRESOLVED",completion="UNRESOLVED",paths="none verified",unknown="everything runtime"})
sys("OUWIGAHARA","Ouwigahara dungeon",{status="UNRESOLVED",
    entry="REFERENCE: first unlock via Blacksmith Togane + portal; later menu queue",
    start="UNRESOLVED",objectives="REFERENCE: floors, cards, milestone cards, boss floors, hearts, points, caches",
    progress="UNRESOLVED",completion="UNRESOLVED",paths="none verified (Dungeon registry: NEEDS BINDING)",unknown="queue, ready, card UI, skip semantics"})
sys("BOSS_HUNT","World bosses",{status="PARTIAL",
    entry="VERIFIED: boss models with HumanoidRootPart, Humanoid, BossInfo",start="VERIFIED: combat",
    objectives="VERIFIED: kill",progress="VERIFIED: Humanoid health",completion="PARTIAL: death handoff (v3.8.4.3, awaiting live)",
    paths="VERIFIED: BossInfo.Chest ('World Events Chest'), ChestRarity, OnlyAtNight",unknown="chest interaction, night clock"})
sys("SKILL_HOTBAR","Skill hotbar",{status="PARTIAL",
    entry="VERIFIED",start="VERIFIED: ComponentsHolder.BottomHolder.SkillsHolder.<n>-Skill.<Skills_nth>.KeyLabel",
    progress="PARTIAL: cast verification by GUI/animation/damage",completion="—",paths="VERIFIED: KeyLabel text F Z X C V B",
    unknown="cooldown overlay semantics (being learned), equip input"})
sys("ESCORT","Escort / carry / deliver",{status="UNRESOLVED",entry="REFERENCE",start="UNRESOLVED",objectives="REFERENCE: capture → carry → deliver",
    progress="UNRESOLVED",completion="UNRESOLVED",paths="none verified",unknown="everything runtime"})
sys("COLLECTION","Collection objectives",{status="UNRESOLVED",entry="REFERENCE",start="UNRESOLVED",objectives="REFERENCE: e.g. Spider Lilies 0/9",
    progress="REFERENCE: quest counter",completion="UNRESOLVED",paths="none verified",unknown="collectible structure"})
sys("SHOP","Shops / Black Marketer / forge",{status="UNRESOLVED",entry="REFERENCE",start="UNRESOLVED",objectives="—",progress="—",
    completion="UNRESOLVED: currency/inventory change",paths="none verified",unknown="shop UI, stock, purchase"})
sys("SKILL_TREE","Skill tree / mastery",{status="UNRESOLVED",entry="REFERENCE",start="UNRESOLVED",objectives="—",progress="UNRESOLVED",
    completion="UNRESOLVED",paths="none verified",unknown="points, unlock action"})
sys("OTHER","Other / custom",{status="UNRESOLVED",entry="—",start="—",objectives="—",progress="—",completion="—",paths="—",unknown="—"})

-- ================= capability provider (v3.8.5.1 · single source of truth) =================
-- UI (Auto Play, Quests, Research, Diagnostics) and runtime gates read ONLY this table.
-- Status vocabulary: VERIFIED · PARTIAL · AWAITING_LIVE · UNRESOLVED · RESEARCH_REQUIRED · DISABLED.
-- A status is raised to VERIFIED only by explicit live evidence (GK.markVerified), never by implementation.
GK.capabilities={}; GK.capOrder={}
local function cap(key,title,status,evidence,detail)
    GK.capabilities[key]={key=key,title=title,status=status,evidence=evidence,detail=detail}; table.insert(GK.capOrder,key)
end
cap("HOTBAR_KEYS","Hotbar key discovery","VERIFIED","Binding report: SkillsHolder.<n>-Skill.<Skills_nth>.KeyLabel = F Z X C V B","KeyLabel promotion")
cap("SKILL_EXECUTION","Skill execution","AWAITING_LIVE","v3.8.4.1 live: skills 0/738 (pre-fix)","verified-cast tracking since v3.8.4.2")
cap("COOLDOWN_LEARNING","Skill cooldown learning","AWAITING_LIVE","none","slot GUI returns to pre-cast signature")
cap("M1_INPUT","M1 input","PARTIAL","v3.8.4.1 live: M1 409 inputs sent (hits not verified)","")
cap("TRAVEL","Travel / teleport / noclip","AWAITING_LIVE","none reported","")
cap("COMBAT_HOVER","Combat hover","PARTIAL","v3.8.4.1 live: hover above Nezura observed","")
cap("RECOVERY_ESCAPE","Recovery escape","AWAITING_LIVE","v3.8.4.1 live: height-only recovery died (pre-fix)","")
cap("BOSS_DEATH_HANDOFF","Boss death → loot handoff","AWAITING_LIVE","v3.8.4.2 live: session never started (pre-fix)","TargetCombatSession since v3.8.4.3")
cap("BOSS_CHEST_OPEN","Boss chest open","UNRESOLVED","BossInfo.Chest identity only; interaction unobserved","")
cap("DROP_COLLECTION","Drop collection","AWAITING_LIVE","v3.8.4.2 live: drops left on ground (pre-fix)","")
cap("MENU_STABILITY","Menu stability in combat","AWAITING_LIVE","v3.8.4.2 live: flicker (pre-fix)","")
cap("QUEST_PROMPT","Quest accept/turn-in via prompt","PARTIAL","none reported","AdaptiveIntel fireproximityprompt + text signature")
cap("QUEST_READ","Quest tracker semantics","UNRESOLVED","zQuestsFrame / QuestionStrip paths only","QuestProbe capturing")
cap("CROW_MISSION","Crow automation","RESEARCH_REQUIRED","none","record the Crow lifecycle with Learn action")
cap("MUZAN_HUNT","Muzan automation","RESEARCH_REQUIRED","none","record the Muzan task flow with Learn action")
cap("BREATHING","Breathing / training","RESEARCH_REQUIRED","none","")
cap("DUNGEON","Ouwigahara","RESEARCH_REQUIRED","none","")
cap("PERFECT_PARRY","Perfect parry","UNRESOLVED","parry input unverified","")
cap("EQUIP","Weapon equip","UNRESOLVED","none","")
cap("NIGHT_CONDITION","Day/night condition","UNRESOLVED","OnlyAtNight metadata only","")
cap("LEARN_ACTION","Learn action probe","AWAITING_LIVE","none","")
function GK.capability(key) return GK.capabilities[key] end
function GK.capable(key) local c=GK.capabilities[key]; return c~=nil and c.status=="VERIFIED" end
-- explicit, evidence-backed promotion only (e.g. after a live test the user confirms)
function GK.markVerified(key,evidence)
    local c=GK.capabilities[key]; if not c then return false end
    c.status="VERIFIED"; c.evidence=tostring(evidence or c.evidence); return true
end
function GK.statusLabel(s)
    return (s=="AWAITING_LIVE" and "PARTIAL · AWAITING LIVE") or (s=="RESEARCH_REQUIRED" and "RESEARCH REQUIRED") or s
end

function GK.recordEvidence(ev)
    table.insert(GK.evidence,ev); while #GK.evidence>30 do table.remove(GK.evidence,1) end
    local s=GK.systems[ev.system] or GK.systems.OTHER
    s.evidence=s.evidence+1; s.lastEvidence=ev.actionName.." · "..ev.confidence
    -- evidence does NOT promote status to VERIFIED automatically; a human maps it first
end

-- ---------- PlayerProgress: verified reads only; candidates are listed, never assumed ----------
local CANDIDATE_WORDS={"wen","race","breath","reputation","mastery","skillpoint","skill_point","points","clan","crow","rank","money","yen","level","exp"}
function GK.readProgress()
    local P={level=nil,exp=nil,expRequired=nil,wen=nil,race=nil,breathing=nil,reputation=nil,mastery=nil,skillPoints=nil,
        crowOwned=nil,crowEquipped=nil,finalSelectionComplete=nil,dungeonUnlocked=nil,candidates={}}
    local RA=RAVYN.ReadAdapter
    if RA then
        local l=RA:getLevel(); if l and l.ok then P.level=l.value end
        local x=RA:getXP(); if x and x.ok then P.exp=x.value end
        local r=RA:getXPRequired(); if r and r.ok then P.expRequired=r.value end
    end
    local LP=game:GetService("Players").LocalPlayer
    if LP then
        local function consider(path,name,value)
            local low=string.lower(name)
            for _,w in ipairs(CANDIDATE_WORDS) do if string.find(low,w,1,true) then
                if #P.candidates<24 then table.insert(P.candidates,{path=path,value=tostring(value)}) end; return end end
        end
        for k,v in pairs(LP:GetAttributes()) do consider("Player@"..k,k,v) end
        local ok,desc=pcall(function() return LP:GetDescendants() end)
        if ok then
            local n=0
            for _,d in ipairs(desc) do
                if d:IsA("ValueBase") and not d:FindFirstAncestorOfClass("PlayerGui") and not d:FindFirstAncestorOfClass("PlayerScripts") then
                    n=n+1; if n>500 then break end
                    local okV,v=pcall(function() return d.Value end); if okV then consider(d:GetFullName(),d.Name,v) end
                end
            end
        end
    end
    GK.progress=P
    return P
end
-- ---------- WorldConditionReader ----------
-- Lighting.ClockTime is only a CANDIDATE: day/night semantics for this game are not verified.
function GK.readWorld()
    local L=game:GetService("Lighting")
    local ok,ct=pcall(function() return L.ClockTime end)
    GK.world={state="UNKNOWN",candidate=ok and string.format("Lighting.ClockTime=%.2f (unverified)",ct) or "none"}
    return GK.world
end
-- ---------- markers / waypoints as evidence (world positions only, never screen/minimap) ----------
local function markerPos(bb)
    local a=bb.Adornee or bb.Parent
    if a and a:IsA("BasePart") then return a.Position,a end
    if a and a:IsA("Attachment") then return a.WorldPosition,a end
    if a and a:IsA("Model") then local ok,cf=pcall(function() return a:GetPivot() end); if ok then return cf.Position,a end end
    return nil
end
function GK.scanMarkers(force)
    local now=os.clock()
    if not force and now-GK.markersAt<8 then return GK.markers end -- v3.9: full scan ≤ every 8s, only while a target is unresolved
    GK.markersAt=now
    local out={}
    local function take(bb)
        if #out>=40 or not bb.Enabled then return end
        local pos,ad=markerPos(bb); if not pos then return end
        local texts={}
        for _,y in ipairs(bb:GetDescendants()) do if (y:IsA("TextLabel") or y:IsA("TextButton")) and y.Visible and y.Text~="" then table.insert(texts,y.Text) end end
        local model=ad and (ad:IsA("Model") and ad or ad:FindFirstAncestorWhichIsA("Model"))
        local npc=model and model:FindFirstChildOfClass("Humanoid") and model.Name or nil
        table.insert(out,{path=bb:GetFullName(),text=table.concat(texts," | "),pos=pos,npc=npc,adornee=ad and ad:GetFullName()})
    end
    local LP=game:GetService("Players").LocalPlayer; local pg=LP and LP:FindFirstChildOfClass("PlayerGui")
    local own=RAVYN._gui
    if pg then for _,d in ipairs(pg:GetDescendants()) do if d:IsA("BillboardGui") and not (own and d:IsDescendantOf(own)) then take(d) end end end
    local ok,desc=pcall(function() return workspace:GetDescendants() end)
    if ok then for i,d in ipairs(desc) do if i>15000 then break end; if d:IsA("BillboardGui") then take(d) end end end
    GK.markers=out
    return out
end
-- quest text → words worth matching (numbers and filler removed)
local STOP={the=true,["and"]=true,kill=true,defeat=true,slay=true,collect=true,talk=true,with=true,from=true,your=true,["return"]=true,
    quest=true,mission=true,reward=true,rewards=true,exp=true,wen=true,progress=true,complete=true,task=true,go=true,to=true}
function GK.questWords(q)
    local words={}
    for _,t in ipairs(q and q.texts or {}) do
        for w in string.gmatch(string.lower(t),"[%a']+") do if #w>=4 and not STOP[w] then words[w]=true end end
    end
    return words
end
-- best marker candidate for an active quest; only acts on a name/text match (never a bare icon)
function GK.questMarker(q)
    local words=GK.questWords(q); local root=liveRoot()
    local best,score=nil,0
    for _,m in ipairs(GK.scanMarkers(false)) do
        local hay=string.lower((m.text or "").." "..(m.npc or ""))
        local s=0; for w in pairs(words) do if string.find(hay,w,1,true) then s=s+1 end end
        if m.npc and s>0 then s=s+1 end
        if s>score or (s==score and s>0 and best and root and (m.pos-root.Position).Magnitude<(best.pos-root.Position).Magnitude) then best,score=m,s end
    end
    if best and score>=1 then return best,score end
    return nil,0
end
-- quest signature without volatile counters (identity survives 0/5 → 4/5)
function GK.questSignature(q)
    if not q or not q.texts then return nil end
    local parts={}
    for _,t in ipairs(q.texts) do local n=string.gsub(string.lower(t),"%d+","#"); table.insert(parts,(string.gsub(n,"%s+"," "))) end
    table.sort(parts)
    return tostring(q.source).."|"..#parts.."|"..string.sub(table.concat(parts," ¦ "),1,240)
end
function RAVYN:GetResearchReport()
    local P=GK.readProgress(); local W=GK.readWorld()
    local lines={"RAVYN RESEARCH REPORT · "..tostring(RAVYN.Version),"",
        "PLAYER PROGRESS (verified)","  level "..tostring(P.level).."  exp "..tostring(P.exp).."/"..tostring(P.expRequired),
        "  wen/race/breathing/reputation/mastery/skillPoints/crow/finalSelection/dungeon: UNRESOLVED",
        "  candidates (not interpreted):"}
    for _,c in ipairs(P.candidates) do table.insert(lines,"    "..c.path.." = "..c.value) end
    table.insert(lines,"WORLD CONDITION: "..W.state.."  ·  "..W.candidate); table.insert(lines,"")
    table.insert(lines,"CAPABILITIES")
    for _,k in ipairs(GK.capOrder) do local c=GK.capabilities[k]; table.insert(lines,string.format("  %-22s %-24s %s",k,GK.statusLabel(c.status),c.evidence)) end
    table.insert(lines,"")
    table.insert(lines,"GAME SYSTEMS")
    for _,k in ipairs(GK.order) do
        local s=GK.systems[k]
        table.insert(lines,string.format("  [%s] %s · evidence %d%s",s.status,s.title,s.evidence,s.lastEvidence and (" · last: "..s.lastEvidence) or ""))
        for _,f in ipairs({"entry","start","startVerify","objectives","progress","completion","paths","unknown","note"}) do
            if s[f] then table.insert(lines,"      "..f..": "..s[f]) end
        end
    end
    local ms=GK.scanMarkers(true); table.insert(lines,""); table.insert(lines,"MARKERS ("..#ms..")")
    for i,m in ipairs(ms) do if i>15 then break end; table.insert(lines,"  "..m.path.."  '"..string.sub(m.text,1,50).."'"..(m.npc and ("  npc "..m.npc) or "")) end
    return result(true,"RESEARCH_REPORT",table.concat(lines,"\n"))
end
function RAVYN:CopyResearchReport()
    local f=(getgenv and getgenv().setclipboard) or G.setclipboard
    local r=self:GetResearchReport(); if type(f)~="function" then return result(false,"SETCLIPBOARD_UNAVAILABLE",r.value) end
    pcall(f,r.value); return result(true,"RESEARCH_REPORT_COPIED")
end
CTX["GK385"]=GK
RAVYN.Logger:log("INFO","GAME_KNOWLEDGE_V385_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("GoV390.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Util=CTX["Util"]
local Config=CTX["Config"]
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
-- v3.9 RAVYN GO: one button, one goal. A runtime profile turns on what the goal needs WITHOUT rewriting the
-- user's saved toggles (SaveSettings writes the originals while the profile is active). The scheduler still
-- decides what runs; nothing new is invented.
local defaults={Goal="AUTO_PROGRESS"}
Config.Default.Go=Util.deepCopy(defaults)
RAVYN.Config.Go=Util.deepMerge(defaults,RAVYN.Config.Go or {})

-- Performance budget (v3.9): AdaptiveIntel read its quest GUI every 0.35s; ~2 Hz is enough.
if RAVYN.Config.AdaptiveIntel and (tonumber(RAVYN.Config.AdaptiveIntel.QuestScanInterval) or 0)<.5 then RAVYN.Config.AdaptiveIntel.QuestScanInterval=.5 end
RAVYN.PerfBudget={combat="30 Hz while a target exists",movement="20 Hz while moving",ui="4 Hz visible page only · 1 Hz hidden",
    questGui="2 Hz",npcScan="snapshot 3 Hz (cached)",workspaceScan="never continuous: source scan ≤ 1/8s only while acquiring; markers ≤ 1/8s only while unresolved",
    research="only while recording",loot="only during a loot session",promptSearch="sphere query ≤ 4 Hz"}

-- goal → profile (config path → runtime value). Availability comes from the capability provider.
local GOALS={
    AUTO_PROGRESS={title="Auto Progress",mode="Smart",profile={["QuestBrain.AutoQuest"]=true,["CrowDirect.Enabled"]=true,["AutoPlayV38.PreFarm"]=true,["AutoPlayV38.BossRotation"]=true}},
    BOSS_FARM={title="Boss Farm",mode="Bosses",profile={["QuestBrain.AutoQuest"]=false,["AutoPlayV38.BossRotation"]=true}},
    QUESTS={title="Quests",mode="Smart",profile={["QuestBrain.AutoQuest"]=true,["CrowDirect.Enabled"]=true,["AutoPlayV38.PreFarm"]=false}},
    BREATHING={title="Breathing",capability="BREATHING"},
    DUNGEON={title="Dungeon",capability="DUNGEON"},
    MONEY={title="Money / resources",capability="MONEY"},
}
local GOAL_ORDER={"AUTO_PROGRESS","BOSS_FARM","QUESTS","BREATHING","DUNGEON","MONEY"}
local COMMON={["Combat.AutoAttack"]=true,["Combat.AutoAbilities"]=true,["CombatMobility.Enabled"]=true,["CombatMobility.FlyFarmFight"]=true,
    ["TravelController.Enabled"]=true,["Loot384.AutoLootAfterKill"]=true,["Loot384.AutoLootChests"]=true}
local GO={active=false,paused=false,goal=nil,startedAt=0,saved={},applying=false,goals=GOALS,order=GOAL_ORDER}
RAVYN.GoState=GO

local function getPath(path) local node=RAVYN.Config; for part in string.gmatch(path,"[^%.]+") do if type(node)~="table" then return nil end; node=node[part] end; return node end
local function setPath(path,v)
    local node=RAVYN.Config; local parts={}; for part in string.gmatch(path,"[^%.]+") do table.insert(parts,part) end
    for i=1,#parts-1 do node=node[parts[i]]; if type(node)~="table" then return false end end
    node[parts[#parts]]=v; return true
end
function GO.available(goal)
    local g=GOALS[goal]; if not g then return false,"UNKNOWN_GOAL" end
    if g.capability then
        local GK=RAVYN.GameKnowledge
        if not (GK and GK.capable(g.capability)) then return false,"RESEARCH_REQUIRED" end
    end
    return true
end
local function applyProfile(goal)
    local g=GOALS[goal]; local values={}
    for k,v in pairs(COMMON) do values[k]=v end
    for k,v in pairs(g.profile or {}) do values[k]=v end
    values["AutoPlayV38.Mode"]=g.mode or "Smart"
    GO.applying=true
    for path,v in pairs(values) do
        if GO.saved[path]==nil then local cur=getPath(path); GO.saved[path]={value=cur} end
        setPath(path,v)
    end
    if GO.saved["Intelligence.AutoPlay"]==nil then GO.saved["Intelligence.AutoPlay"]={value=getPath("Intelligence.AutoPlay")} end
    local r=RAVYN:SetAutoPlay(true)
    GO.applying=false
    return r
end
local function restoreProfile()
    GO.applying=true
    for path,rec in pairs(GO.saved) do setPath(path,rec.value) end
    GO.saved={}
    GO.applying=false
end
function RAVYN:Go(goal)
    goal=goal or self.Config.Go.Goal
    local ok,why=GO.available(goal); if not ok then return result(false,why,{goal=goal}) end
    if GO.active and GO.goal~=goal then restoreProfile() end
    self.Config.Go.Goal=goal
    GO.active=true; GO.paused=false; GO.goal=goal; GO.startedAt=os.clock()
    if self.FSM.state=="PAUSED" then self:Resume() end
    local r=applyProfile(goal)
    if self.FSM.state=="STOPPED" then self:Start() end
    self.Logger:log("INFO","GO_START",{goal=goal})
    if self.AutoPlay384 and self.AutoPlay384.push then self.AutoPlay384.push("RAVYN started · "..GOALS[goal].title,"success") end
    return result(true,"RAVYN_GO",{goal=goal,autoplay=r and r.code})
end
function RAVYN:GoPause()
    if not GO.active then return result(false,"NOT_ACTIVE") end
    if GO.paused then GO.paused=false; if self.FSM.state=="PAUSED" then self:Resume() end; return result(true,"RESUMED") end
    GO.paused=true; if self.FSM.state=="RUNNING" then self:Pause() end
    return result(true,"PAUSED")
end
function RAVYN:GoSetGoal(goal)
    local ok,why=GO.available(goal); if not ok then return result(false,why,{goal=goal}) end
    self.Config.Go.Goal=goal
    if GO.active then return self:Go(goal) end
    return self:SetConfig("Go.Goal",goal)
end
-- keep user's saved toggles untouched by the runtime profile
local baseSave=RAVYN.SaveSettings
function RAVYN:SaveSettings(...)
    if not next(GO.saved) then return baseSave(self,...) end
    local live={}
    for path,rec in pairs(GO.saved) do live[path]=getPath(path); setPath(path,rec.value) end
    local ok,r=pcall(baseSave,self,...)
    for path,v in pairs(live) do setPath(path,v) end
    if not ok then error(r) end
    return r
end
-- a user change to a profile-managed setting while GO runs is a real choice: keep it as the saved value
local baseSetConfig=RAVYN.SetConfig
function RAVYN:SetConfig(path,value)
    local r=baseSetConfig(self,path,value)
    if r and r.ok and not GO.applying and GO.saved[path]~=nil then GO.saved[path]={value=value} end
    return r
end
local baseStop=RAVYN.Stop
function RAVYN:Stop()
    local was=GO.active
    GO.active=false; GO.paused=false
    if next(GO.saved) then restoreProfile() end
    local r=baseStop(self)
    if was then task.defer(function() pcall(function() RAVYN:SaveSettings() end) end) end
    return r
end
-- simple state for the UI: READY → STARTING → FINDING OBJECTIVE → ACTIVE (· PAUSED / STOPPED)
function GO.state()
    local fsm=RAVYN.FSM and RAVYN.FSM.state
    if not GO.active then return fsm=="RUNNING" and "MANUAL" or "READY" end
    if GO.paused or fsm=="PAUSED" then return "PAUSED" end
    if os.clock()-GO.startedAt<1.2 then return "STARTING" end
    local JS=RAVYN.JobScheduler; local LC=RAVYN.LootController
    if LiveAction.target or (LC and LC.active) or (JS and JS.job~="IDLE") then return "ACTIVE" end
    return "FINDING OBJECTIVE"
end
function RAVYN:GetGoStatus() return result(true,"GO_STATUS",{active=GO.active,paused=GO.paused,goal=GO.goal or self.Config.Go.Goal,state=GO.state()}) end
CTX["GO390"]=GO
RAVYN.Logger:log("INFO","RAVYN_GO_V390_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("RuntimeSchemaV391.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
-- v3.9.1 RuntimeSchema + read-only DataAdapters.
-- Rules: never require() any ModuleScript (names only, code is never executed); never invoke command modules
-- (e.g. OCIFolder Give/Damage/CompleteQuest…) — they are identity evidence only; never fire remotes;
-- the current player's data is ONLY Player_Service.Data.<LocalPlayer.Name> (no fallback to other players).
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local LP=Players.LocalPlayer
local SCH={builtAt=nil,nodes={},identities={},errors={}}
RAVYN.RuntimeSchema=SCH

local function path(root,...)
    local cur=root
    for _,name in ipairs({...}) do if not cur then return nil end; cur=cur:FindFirstChild(name) end
    return cur
end
local function childNames(inst,limit)
    local out={}; if not inst then return out end
    for i,c in ipairs(inst:GetChildren()) do if i>(limit or 200) then break end; table.insert(out,c.Name) end
    table.sort(out); return out
end
-- one-shot identity lookup in the world (C-side recursive FindFirstChild; never continuous)
local function worldFind(name)
    local ok,inst=pcall(function() return workspace:FindFirstChild(name,true) end)
    if not ok or not inst then return nil end
    local pos=nil
    if inst:IsA("BasePart") then pos=inst.Position elseif inst:IsA("Model") then local okP,cf=pcall(function() return inst:GetPivot() end); if okP then pos=cf.Position end end
    return {inst=inst,path=inst:GetFullName(),class=inst.ClassName,pos=pos}
end

-- ---------- LocalPlayerDataResolver + ActiveSlotResolver (v3.9.1.1) ----------
-- Layout evidence: Player_Service.Data.<LocalPlayer.Name>.slots.<SlotX>.{Inventory,Toolbar,Powers,Quests,…}
-- Local player only. No hard-coded slot. Without reliable evidence: ACTIVE_SLOT_UNRESOLVED.
local SECTION_NAMES={Inventory=true,Toolbar=true,Powers=true,Quests=true,ItemLoadouts=true,MasteryProgressionList=true,SkillTreeUnlockedList=true}
local SLOT_KEYS={"CurrentSlot","ActiveSlot","SelectedSlot","CurrentSave","ActiveSave","SelectedSave","Slot","SaveSlot"}
local function hasSections(inst) if not inst then return 0 end; local n=0; for _,c in ipairs(inst:GetChildren()) do if SECTION_NAMES[c.Name] then n=n+1 end end; return n end
local function slotFromValue(slots,v)
    if v==nil or not slots then return nil end
    local s=tostring(v)
    return slots:FindFirstChild(s) or slots:FindFirstChild("Slot"..s) or slots:FindFirstChild("slot"..s) or nil
end
function SCH.resolveLocalData(root)
    local R={status="PLAYER_DATA_NOT_FOUND",me=nil,layout=nil,slot=nil,source=nil,candidates={}}
    if not (root and LP) then return R end
    local me=root:FindFirstChild(LP.Name) -- local player only; never another player's node
    if not me then return R end
    R.me=me
    local slots=me:FindFirstChild("slots") or me:FindFirstChild("Slots")
    if not slots then
        if hasSections(me)>0 then R.status="RESOLVED"; R.layout="DIRECT"; R.slot=me; R.source="SECTIONS_DIRECT_UNDER_PLAYER" else R.status="NO_SLOTS_OR_SECTIONS" end
        return R
    end
    R.layout="SLOTS"
    for _,c in ipairs(slots:GetChildren()) do
        local attrs=c:GetAttributes(); local flag=nil
        for _,k in ipairs({"Active","Selected","Current","IsActive","IsSelected","InUse"}) do if attrs[k]==true then flag=k end end
        table.insert(R.candidates,{name=c.Name,sections=hasSections(c),flag=flag})
    end
    table.sort(R.candidates,function(a,b) return a.name<b.name end)
    -- 1) explicit current/active slot value or attribute (player node, slots container, LocalPlayer)
    for _,holder in ipairs({me,slots,LP}) do
        for _,k in ipairs(SLOT_KEYS) do
            local vObj=holder~=LP and holder:FindFirstChild(k)
            local v=(vObj and vObj:IsA("ValueBase") and vObj.Value) or holder:GetAttribute(k)
            local s=slotFromValue(slots,v)
            if s then R.status="RESOLVED"; R.slot=s; R.source=(holder==LP and "LocalPlayer" or holder.Name).."."..k.."="..tostring(v); return R end
        end
    end
    -- 2) a slot flagged active/selected by attribute
    for _,c in ipairs(R.candidates) do if c.flag then R.status="RESOLVED"; R.slot=slots:FindFirstChild(c.name); R.source="attribute "..c.flag.." on "..c.name; return R end end
    -- 3) only one slot exists → unambiguous
    local withData={}; for _,c in ipairs(R.candidates) do if c.sections>0 then table.insert(withData,c) end end
    if #R.candidates==1 then R.status="RESOLVED"; R.slot=slots:GetChildren()[1]; R.source="ONLY_SLOT"; return R end
    R.status="ACTIVE_SLOT_UNRESOLVED"; R.withData=#withData
    return R
end

-- ---------- schema build (on demand, cached) ----------
local TRAINERS={"Flame","Thunder","Water","Wind","Stone","Serpent","Insect","Sound"}
local WORLD_IDENTITIES={"Muzan","Refiner Hagane","Black Marketer","Harvester of Souls Zurinyz","Yeti Summon","Sealed Chest T1","Sealed Chest T2","Sealed Chest T3"}
-- light build: containers + names only (cheap). full build adds one-shot world identity lookups (explicit only).
function SCH.build(full)
    local now=os.clock(); local N={}; local I={}
    N.playerDataRoot=path(RS,"Player_Service","Data")
    local R=SCH.resolveLocalData(N.playerDataRoot)
    SCH.slot=R
    N.playerData=R.me                                   -- local player node (whole, all local slots)
    N.sectionRoot=(R.status=="RESOLVED") and R.slot or nil -- where Inventory/Quests/… live
    N.questStates=path(RS,"QuestStates")
    N.ouwlandContent=path(RS,"Ouwland","Content")
    N.dialogueQuests=N.ouwlandContent and path(N.ouwlandContent,"Misc","NpcContents","Dialogues","Quests")
    N.dialogueFunctions=N.ouwlandContent and path(N.ouwlandContent,"Misc","NpcContents","Dialogues","Functions")
    N.dialogueYap=N.ouwlandContent and path(N.ouwlandContent,"Misc","NpcContents","Dialogues","Yap")
    N.npcs=N.ouwlandContent and path(N.ouwlandContent,"Misc","Npcs")
    N.skills=path(RS,"Skills")
    N.training=workspace:FindFirstChild("Training")
    N.humanoidRegions=path(workspace,"Humanoids","Regions")
    N.debree=workspace:FindFirstChild("Debree")
    local okO,oci=pcall(function() return RS:FindFirstChild("OCIFolder",true) end); N.ociFolder=okO and oci or nil
    -- identities (names only)
    I.questStates=childNames(N.questStates,400)
    I.playerDataSections=N.sectionRoot and childNames(N.sectionRoot,60) or {}
    I.crowBossHuntDialogues=childNames(N.dialogueQuests and N.dialogueQuests:FindFirstChild("Boss Hunts"),100)
    I.crowBossHuntNpcs=childNames(N.npcs and N.npcs:FindFirstChild("Boss Hunts"),100)
    I.crowBossHuntsFound=(N.dialogueQuests and N.dialogueQuests:FindFirstChild("Boss Hunts")~=nil) or (N.npcs and N.npcs:FindFirstChild("Boss Hunts")~=nil) or false
    I.muzanQuestState=N.questStates and N.questStates:FindFirstChild("Muzan Quest")~=nil or false
    I.muzanDialogue={actions=N.dialogueFunctions and N.dialogueFunctions:FindFirstChild("MuzanActions")~=nil or false,
        quests=N.dialogueQuests and N.dialogueQuests:FindFirstChild("Muzan")~=nil or false,yap=N.dialogueYap and N.dialogueYap:FindFirstChild("Muzan")~=nil or false}
    I.merchantActions=N.dialogueFunctions and N.dialogueFunctions:FindFirstChild("MerchantActions")~=nil or false
    I.trainingStations=childNames(N.training,120)
    I.skillsModules=#childNames(N.skills,2000)
    I.ociCommands=childNames(N.ociFolder,200) -- EVIDENCE ONLY: never required/invoked
    -- IDENTITY (static content; independent of what is streamed right now)
    I.contentIdentity={}
    local function contentFind(name)
        if not N.ouwlandContent then return nil end
        local ok,inst=pcall(function() return N.ouwlandContent:FindFirstChild(name,true) end)
        return ok and inst and inst:GetFullName() or nil
    end
    for _,n in ipairs(WORLD_IDENTITIES) do I.contentIdentity[n]=contentFind(n) end
    for _,t in ipairs(TRAINERS) do I.contentIdentity[t.." Trainer"]=contentFind(t.." Trainer") end
    -- Final Selection identity: region evidence (not only a QuestStates name)
    local fsr=N.humanoidRegions and N.humanoidRegions:FindFirstChild("Final Selection Plains")
    I.finalSelectionRegion=fsr and fsr:GetFullName() or nil
    if full then
        -- PRESENCE (streamed in the world now); never lowers identity
        I.finalSelectionWorld={}
        for _,c in ipairs(workspace:GetChildren()) do if string.find(string.lower(c.Name),"final selection",1,true) then table.insert(I.finalSelectionWorld,c:GetFullName()) end end
        I.trainers={}
        for _,t in ipairs(TRAINERS) do I.trainers[t]=worldFind(t.." Trainer") end
        I.world={}
        for _,n in ipairs(WORLD_IDENTITIES) do I.world[n]=worldFind(n) end
        SCH.fullAt=now
    else I.trainers=SCH.identities.trainers or {}; I.world=SCH.identities.world or {}; I.finalSelectionWorld=SCH.identities.finalSelectionWorld or {} end
    SCH.nodes=N; SCH.identities=I; SCH.builtAt=now
    return SCH
end
function SCH.get(maxAge) if not SCH.builtAt or os.clock()-SCH.builtAt>(maxAge or 120) then pcall(SCH.build,false) end; return SCH end

-- ---------- generic read-only decoder (bounded) ----------
local function decodeValue(v)
    if type(v)=="string" and (string.sub(v,1,1)=="{" or string.sub(v,1,1)=="[") then
        local ok,t=pcall(function() return HttpService:JSONDecode(v) end); if ok then return t,"JSON" end
    end
    return v,nil
end
local function readTree(inst,depth,budget)
    budget=budget or {n=0}; depth=depth or 0
    if not inst or depth>6 or budget.n>900 then return nil end
    budget.n=budget.n+1
    local node={name=inst.Name,class=inst.ClassName}
    if inst:IsA("ValueBase") then local ok,v=pcall(function() return inst.Value end); if ok then node.value,node.encoding=decodeValue(v) end end
    local okA,attrs=pcall(function() return inst:GetAttributes() end); if okA and next(attrs) then node.attrs=attrs end
    local kids=inst:GetChildren()
    if #kids>0 then node.children={}; for _,c in ipairs(kids) do local n=readTree(c,depth+1,budget); if n then node.children[c.Name]=n end end end
    return node
end
SCH.readTree=readTree

-- ---------- adapters (read-only views) ----------
local A={}
RAVYN.DataAdapters=A
local function section(name)
    local s=SCH.get(); local root=s.nodes.sectionRoot
    if not root then return nil,(SCH.slot and SCH.slot.status) or "PLAYER_DATA_NOT_FOUND" end
    local inst=root:FindFirstChild(name); if not inst then return nil,"SECTION_NOT_FOUND:"..name end
    return readTree(inst),nil
end
A.PlayerData=function()
    local s=SCH.get(); local R=SCH.slot or {}
    if not s.nodes.playerData then return nil,"PLAYER_DATA_NOT_FOUND" end
    return {status=R.status,layout=R.layout,slot=R.slot and R.slot.Name,source=R.source,candidates=R.candidates,sections=s.identities.playerDataSections,path=s.nodes.playerData:GetFullName()}
end
A.Inventory=function() return section("Inventory") end
A.Toolbar=function() return section("Toolbar") end
A.Powers=function() return section("Powers") end
A.ItemLoadouts=function() return section("ItemLoadouts") end
A.Mastery=function() return section("MasteryProgressionList") end
A.SkillTree=function() return section("SkillTreeUnlockedList") end
-- Quests: replicated data vs zQuestsFrame GUI, cross-checked; QuestStates names are identities (never required)
function A.Quests()
    local data,err=section("Quests")
    local names={}
    if data and data.children then for k in pairs(data.children) do table.insert(names,k) end end
    table.sort(names)
    local AI=RAVYN.AdaptiveIntel; local gui=string.lower(AI and AI.quest and AI.quest.joined or "")
    local known=SCH.get().identities.questStates or {}
    local inGui,onlyData={},{}
    for _,n in ipairs(names) do if gui~="" and string.find(gui,string.lower(n),1,true) then table.insert(inGui,n) else table.insert(onlyData,n) end end
    local identity=nil
    for _,n in ipairs(known) do if gui~="" and string.find(gui,string.lower(n),1,true) then identity=n; break end end
    return {dataQuests=names,dataError=err,guiActive=gui~="",agreeing=inGui,onlyInData=onlyData,questStateIdentity=identity,
        agreement=(err and not string.find(err,"SECTION_NOT_FOUND",1,true) and "DATA_UNRESOLVED") or (gui=="" and #names==0 and "BOTH_EMPTY") or ((#inGui>0) and "MATCH") or ((gui~="" and #names==0) and "GUI_ONLY") or ((gui=="" and #names>0) and "DATA_ONLY") or "MISMATCH"}
end
function A.Dialogue()
    local s=SCH.get(); local N=s.nodes
    return {quests=childNames(N.dialogueQuests,300),functions=childNames(N.dialogueFunctions,300),yap=childNames(N.dialogueYap,300)}
end
function A.Training()
    local s=SCH.get(); local out={stations={},trainers={}}
    local tr=s.nodes.training
    if tr then
        for _,st in ipairs(tr:GetChildren()) do
            local prompts={}
            for i,d in ipairs(st:GetDescendants()) do if i>200 then break end
                if d:IsA("ProximityPrompt") then table.insert(prompts,d.ActionText.."|"..d.ObjectText) end end
            table.insert(out.stations,{name=st.Name,class=st.ClassName,prompts=prompts})
        end
    end
    for t,f in pairs(s.identities.trainers or {}) do out.trainers[t]=f and f.path or false end
    return out
end
function A.Boss()
    local s=SCH.get(); local metas={}
    for name,m in pairs((RAVYN.BossMeta and RAVYN.BossMeta.byName) or {}) do metas[name]={chest=m.chest,onlyAtNight=m.onlyAtNight,streamed=m.streamed} end
    return {bossHuntDialogues=s.identities.crowBossHuntDialogues,bossHuntNpcs=s.identities.crowBossHuntNpcs,bossInfo=metas}
end
function A.WorldActivity()
    local s=SCH.get(); local out={}
    for n,f in pairs(s.identities.world or {}) do out[n]=f and {path=f.path,class=f.class} or false end
    return out
end
function RAVYN:GetRuntimeSchemaReport()
    local s=SCH.build(true); local I=s.identities; local N=s.nodes
    local function yes(x) return x and "FOUND" or "not found in this context" end
    local L={"RUNTIME SCHEMA · "..tostring(RAVYN.Version).." · read-only · no require() · command modules never invoked",""}
    table.insert(L,"Player_Service.Data.<LocalPlayer>: "..(N.playerData and N.playerData:GetFullName() or "not found"))
    local R=SCH.slot or {}
    table.insert(L,"  layout: "..tostring(R.layout).."  ·  active slot: "..tostring(R.status)..(R.slot and (" → "..R.slot.Name) or "")..(R.source and ("  (evidence: "..R.source..")") or ""))
    for _,c in ipairs(R.candidates or {}) do table.insert(L,"    slot candidate "..c.name.."  sections "..c.sections..(c.flag and ("  flag "..c.flag) or "")) end
    table.insert(L,"  sections: "..(#I.playerDataSections>0 and table.concat(I.playerDataSections,", ") or "unresolved"))
    table.insert(L,"QuestStates: "..#I.questStates.." identities")
    for i,n in ipairs(I.questStates) do if i>60 then table.insert(L,"   …"); break end; table.insert(L,"   "..n) end
    table.insert(L,"Crow · Boss Hunts: "..yes(I.crowBossHuntsFound).."  dialogues "..#I.crowBossHuntDialogues.."  npcs "..#I.crowBossHuntNpcs)
    table.insert(L,"Muzan: QuestState "..yes(I.muzanQuestState).." · MuzanActions "..yes(I.muzanDialogue.actions).." · Quests.Muzan "..yes(I.muzanDialogue.quests).." · Yap.Muzan "..yes(I.muzanDialogue.yap))
    table.insert(L,"Trainers (identity · presence):")
    for _,t in ipairs(TRAINERS) do local f=I.trainers[t]; local id=I.contentIdentity[t.." Trainer"]
        table.insert(L,"   "..t.." Trainer: "..(id and "IDENTITY" or "identity not found").." · "..(f and ("PRESENT "..f.path) or "NOT_STREAMED")) end
    table.insert(L,"Final Selection: region "..tostring(I.finalSelectionRegion).."  ·  world "..(#(I.finalSelectionWorld or {})>0 and table.concat(I.finalSelectionWorld,", ") or "none streamed"))
    table.insert(L,"Workspace.Training: "..table.concat(I.trainingStations,", "))
    table.insert(L,"World identities (identity · presence):")
    for _,n in ipairs(WORLD_IDENTITIES) do local f=I.world[n]; local id=I.contentIdentity[n]
        table.insert(L,"   "..n..": "..(id and ("IDENTITY "..id) or "identity not found").." · "..(f and ("PRESENT "..f.class.." "..f.path) or "NOT_STREAMED")) end
    table.insert(L,"MerchantActions: "..yes(I.merchantActions).."  ·  Skills modules: "..I.skillsModules)
    table.insert(L,"OCIFolder (evidence only, never invoked): "..(#I.ociCommands>0 and table.concat(I.ociCommands,", ") or "not found"))
    table.insert(L,"Humanoids.Regions: "..yes(N.humanoidRegions).."  ·  Debree: "..yes(N.debree))
    local q=A.Quests()
    table.insert(L,""); table.insert(L,"Quest cross-check: "..q.agreement.."  data="..table.concat(q.dataQuests,", ").."  identity="..tostring(q.questStateIdentity))
    return result(true,"RUNTIME_SCHEMA",table.concat(L,"\n"))
end
CTX["SCH391"]=SCH
RAVYN.Logger:log("INFO","RUNTIME_SCHEMA_V391_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("UniversalTraceV391.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
-- v3.9.1 UniversalTrace: one START LEARNING. Records causes (prompt / game button / key) and effects
-- (GUI, quest text, player data, tools, markers, NPCs, training), groups them ACTION → EFFECTS, infers
-- CANDIDATE semantics. Never marks anything VERIFIED. All hooks exist only while tracing.
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local PPS=game:GetService("ProximityPromptService")
local LP=Players.LocalPlayer
local SCH=CTX["SCH391"]
local TR={active=false,events={},groups={},ambient={},conns={},hooked={},hookCount=0,seq=0,last=nil,candidates={}}
RAVYN.Trace=TR
local MAX_EVENTS,MAX_HOOKS=4000,3000
local MOVE_KEYS={W=true,A=true,S=true,D=true,Space=true,LeftShift=true,RightShift=true,LeftControl=true,Unknown=true}
local function short(s,n) s=string.gsub(tostring(s or ""),"[\r\n]+"," "); return #s>(n or 70) and (string.sub(s,1,n or 70).."…") or s end
local function esc(s) return (string.gsub(tostring(s),"[%%%.%-%+%*%?%[%]%^%$%(%)]","%%%0")) end
local function rel(inst)
    local p=inst:GetFullName()
    local me=esc(LP and LP.Name or "_")
    p=string.gsub(p,"^Players%."..me.."%.PlayerGui%.","GUI:")
    local slot=SCH and SCH.slot and SCH.slot.slot and SCH.slot.layout=="SLOTS" and SCH.slot.slot.Name
    if slot then p=string.gsub(p,"^ReplicatedStorage%.Player_Service%.Data%."..me.."%.[sS]lots%."..esc(slot).."%.","DATA:") end
    p=string.gsub(p,"^ReplicatedStorage%.Player_Service%.Data%."..me.."%.[sS]lots%.([^%.]+)%.","DATA[%1]:")
    p=string.gsub(p,"^ReplicatedStorage%.Player_Service%.Data%."..me.."%.","DATA:")
    p=string.gsub(p,"^Workspace%.","WS:")
    return p
end
local function conn(sig,fn) if TR.hookCount>=MAX_HOOKS then return end; TR.hookCount=TR.hookCount+1; table.insert(TR.conns,sig:Connect(fn)) end

-- ---------- event intake + causal grouping ----------
local function push(kind,text,isCause)
    if not TR.active or #TR.events>=MAX_EVENTS then return end
    local now=os.clock(); local t=now-TR.startedAt
    local ev={t=t,kind=kind,text=text}
    table.insert(TR.events,ev)
    if isCause then
        local g={cause=ev,effects={},openUntil=now+3,hardUntil=now+6}
        table.insert(TR.groups,g); TR.open=g
        while #TR.groups>200 do table.remove(TR.groups,1) end
        return
    end
    local g=TR.open
    if g and now<=g.openUntil then
        table.insert(g.effects,ev); g.openUntil=math.min(g.hardUntil,math.max(g.openUntil,now+1))
    else
        TR.open=nil
        local slice=math.floor(t/5)
        local a=TR.ambient[#TR.ambient]
        if not a or a.slice~=slice then a={slice=slice,effects={}}; table.insert(TR.ambient,a); while #TR.ambient>120 do table.remove(TR.ambient,1) end end
        if #a.effects<60 then table.insert(a.effects,ev) end
    end
end
-- ---------- hooks ----------
local function isInterestingGui(d)
    if d:IsA("LayerCollector") or d:IsA("GuiButton") then return true end
    if (d:IsA("TextLabel") or d:IsA("TextBox")) and d.Text~="" then return true end
    return d:IsA("GuiObject") and d.Parent~=nil and d.Parent:IsA("LayerCollector")
end
-- Typed hook flags: the same Instance may need more than one observer.
-- Example: a TextButton needs both Activated and Text-change hooks.
local function hookFlags(inst)
    local f=TR.hooked[inst]
    if type(f)~="table" then f={}; TR.hooked[inst]=f end
    return f
end
local function hookButton(d,own)
    if not d:IsA("GuiButton") or (own and d:IsDescendantOf(own)) then return end
    local f=hookFlags(d); if f.button then return end; f.button=true
    conn(d.Activated,function()
        local txt=d:IsA("TextButton") and d.Text or ""; local lbl=d:FindFirstChildWhichIsA("TextLabel",true)
        push("BUTTON",rel(d).." '"..short(txt~="" and txt or (lbl and lbl.Text) or "",40).."'",true)
    end)
end
local function hookText(d)
    if not (d:IsA("TextLabel") or d:IsA("TextButton")) then return end
    local f=hookFlags(d); if f.text then return end; f.text=true
    conn(d:GetPropertyChangedSignal("Text"),function() push("TEXT",rel(d).." = "..short(d.Text,80)) end)
end
local function hookValue(d)
    if not d:IsA("ValueBase") then return end
    local f=hookFlags(d); if f.value then return end; f.value=true
    conn(d.Changed,function(v) push("DATA_CHANGED",rel(d).." = "..short(tostring(v),80)) end)
end
local function startHooks()
    local own=RAVYN._gui
    local pg=LP and LP:FindFirstChildOfClass("PlayerGui")
    conn(PPS.PromptTriggered,function(pr,plr) if plr==LP then push("PROMPT",rel(pr).." ["..pr.ActionText.."|"..pr.ObjectText.."]",true) end end)
    conn(UIS.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.Keyboard and not MOVE_KEYS[input.KeyCode.Name] then push("KEY",input.KeyCode.Name,true) end
    end)
    if pg then
        for i,d in ipairs(pg:GetDescendants()) do if i>6000 then break end; hookButton(d,own) end
        conn(pg.DescendantAdded,function(d)
            if own and d:IsDescendantOf(own) then return end
            hookButton(d,own)
            if isInterestingGui(d) then push("GUI_ADDED",rel(d)..((d:IsA("TextLabel") or d:IsA("TextButton")) and (" '"..short(d.Text,40).."'") or "")) end
        end)
        conn(pg.DescendantRemoving,function(d)
            if own and d:IsDescendantOf(own) then return end
            if isInterestingGui(d) then push("GUI_REMOVED",rel(d)) end
        end)
        -- known quest GUI text
        local a=pg:FindFirstChild("ComponentsHolder"); local b=a and a:FindFirstChild("LeftCenterFramesHolder")
        local roots={b and b:FindFirstChild("zQuestsFrame"),pg:FindFirstChild("QuestionStrip",true)}
        for _,r in ipairs(roots) do if r then
            for i,d in ipairs(r:GetDescendants()) do if i>800 then break end; hookText(d) end
            conn(r.DescendantAdded,function(d) hookText(d) end)
        end end
    end
    -- player data (local player only)
    local pd=SCH and SCH.get().nodes.playerData
    if pd then
        for i,d in ipairs(pd:GetDescendants()) do if i>1500 then break end; hookValue(d) end
        conn(pd.DescendantAdded,function(d) hookValue(d); push("DATA_ADDED",rel(d)..(d:IsA("ValueBase") and (" = "..short(tostring(d.Value),60)) or "")) end)
        conn(pd.DescendantRemoving,function(d) push("DATA_REMOVED",rel(d)) end)
        conn(pd.AttributeChanged,function(k) push("DATA_ATTR","DATA@"..k.." = "..short(tostring(pd:GetAttribute(k)),60)) end)
    end
    if LP then conn(LP.AttributeChanged,function(k) push("PLAYER_ATTR","Player@"..k.." = "..short(tostring(LP:GetAttribute(k)),60)) end) end
    -- tools
    local bp=LP and LP:FindFirstChildOfClass("Backpack")
    if bp then conn(bp.ChildAdded,function(c) push("TOOL","backpack + "..c.Name) end); conn(bp.ChildRemoved,function(c) push("TOOL","backpack - "..c.Name) end) end
    local char=LP and LP.Character
    if char then conn(char.ChildAdded,function(c) if c:IsA("Tool") then push("TOOL","equipped "..c.Name) end end); conn(char.ChildRemoved,function(c) if c:IsA("Tool") then push("TOOL","unequipped "..c.Name) end end) end
    -- markers (world + gui), cheap class filter
    conn(workspace.DescendantAdded,function(d) if d:IsA("BillboardGui") or d:IsA("Highlight") or d:IsA("Beam") then push("MARKER_ADDED",rel(d)) end end)
    conn(workspace.DescendantRemoving,function(d) if d:IsA("BillboardGui") or d:IsA("Highlight") or d:IsA("Beam") then push("MARKER_REMOVED",rel(d)) end end)
    -- NPC spawn/despawn/death in Humanoids.Regions.
    -- NPCs live in Workspace.Humanoids.Regions.<Region>.ActiveNpcs.
    -- Event-driven only: no health polling and no continuous Workspace scans.
    local regions=SCH and SCH.get().nodes.humanoidRegions
    if regions then
        local function hookNpcDeath(r,entity)
            if not entity then return end
            local ef=hookFlags(entity)
            if ef.deathwatch then return end
            ef.deathwatch=true

            local function attachHumanoid(h)
                if not (h and h:IsA("Humanoid")) then return end
                local hf=hookFlags(h); if hf.death then return end; hf.death=true
                local model=h:FindFirstAncestorWhichIsA("Model") or entity
                local npcName=(model and model.Name) or entity.Name
                local modelPath=model and rel(model) or rel(entity)
                local previous=tonumber(h.Health) or 0
                local function emitDeath(source)
                    if hf.deathEmitted then return end
                    hf.deathEmitted=true
                    push("NPC_DIED",r.Name.." "..npcName.." "..modelPath.." ["..source.."]")
                end
                conn(h.Died,function() emitDeath("Died") end)
                conn(h:GetPropertyChangedSignal("Health"),function()
                    local now=tonumber(h.Health) or 0
                    if previous>0 and now<=0 then emitDeath("HealthZero") end
                    previous=now
                end)
            end

            local h=entity:IsA("Humanoid") and entity or entity:FindFirstChildWhichIsA("Humanoid",true)
            if h then attachHumanoid(h) end
            -- Some streamed NPC holders receive their model/humanoid after the holder itself is inserted.
            conn(entity.DescendantAdded,function(d) if d:IsA("Humanoid") then attachHumanoid(d) end end)
        end

        local function hookActive(r,an)
            local af=hookFlags(an); if af.container then return end; af.container=true
            for _,c in ipairs(an:GetChildren()) do hookNpcDeath(r,c) end
            conn(an.ChildAdded,function(c)
                push("NPC_SPAWN",r.Name.." + "..c.Name)
                hookNpcDeath(r,c)
            end)
            conn(an.ChildRemoved,function(c) push("NPC_DESPAWN",r.Name.." - "..c.Name) end)
        end
        local function hookRegion(r)
            local rf=hookFlags(r); if rf.region then return end; rf.region=true
            local an=r:FindFirstChild("ActiveNpcs"); if an then hookActive(r,an) end
            conn(r.ChildAdded,function(c) if c.Name=="ActiveNpcs" then hookActive(r,c) end end)
        end
        for _,r in ipairs(regions:GetChildren()) do hookRegion(r) end
        conn(regions.ChildAdded,function(r) hookRegion(r) end)
    end
    -- training stations
    local tr=SCH and SCH.get().nodes.training
    if tr then
        conn(tr.DescendantAdded,function(d) if d:IsA("ProximityPrompt") or d:IsA("Model") or d:IsA("GuiBase") then push("TRAINING",rel(d).." added") end end)
        conn(tr.DescendantRemoving,function(d) if d:IsA("ProximityPrompt") or d:IsA("Model") then push("TRAINING",rel(d).." removed") end end)
        for i,d in ipairs(tr:GetDescendants()) do
            if i>1500 then break end
            if d:IsA("ProximityPrompt") then conn(d:GetPropertyChangedSignal("Enabled"),function() push("TRAINING",rel(d).." enabled="..tostring(d.Enabled)) end) end
        end
    end
end
local function stopHooks()
    TR.hooksUsed=TR.hookCount -- preserve for the report before resetting
    for _,c in ipairs(TR.conns) do pcall(function() c:Disconnect() end) end
    TR.conns={}; TR.hooked={}; TR.hookCount=0; TR.open=nil
end

-- ---------- candidate semantics (never VERIFIED) ----------
local function has(effects,kind,pattern)
    for _,e in ipairs(effects) do if e.kind==kind and (not pattern or string.find(string.lower(e.text),pattern,1,true)) then return e end end
    return nil
end
local function infer()
    local C={}; local seen={}
    local function add(conf,text)
        if seen[text] then return end
        seen[text]=true
        table.insert(C,{confidence=conf,text=text})
    end
    for _,g in ipairs(TR.groups) do
        local c=g.cause; local ct=string.lower(c.text); local E=g.effects
        local questGui=has(E,"TEXT","zquestsframe") or has(E,"GUI_ADDED","zquestsframe")
        local questData=has(E,"DATA_ADDED","data:quests") or has(E,"DATA_CHANGED","data:quests")
        if c.kind=="BUTTON" and (string.find(ct,"claim",1,true) or string.find(ct,"accept",1,true) or string.find(ct,"start",1,true)) and (questGui or questData) then
            add((questGui and questData) and "HIGH" or "MEDIUM","quest accept action: "..c.text..(questData and (" → "..questData.text) or "")..(questGui and (" → "..questGui.text) or ""))
        elseif (c.kind=="PROMPT" or c.kind=="BUTTON") and (questGui or questData) then
            add("MEDIUM","action changes quest state: "..c.text)
        end
        if c.kind=="PROMPT" and has(E,"GUI_ADDED") then add("MEDIUM","prompt opens GUI: "..c.text.." → "..has(E,"GUI_ADDED").text) end
        local inv=has(E,"DATA_ADDED","data:inventory") or has(E,"DATA_CHANGED","data:inventory")
        if inv then add("MEDIUM","action changes inventory: "..c.text.." → "..inv.text) end
        local mk=has(E,"MARKER_ADDED"); if mk and (questGui or questData) then add("MEDIUM","objective marker after "..c.text.." → "..mk.text) end
        local trn=has(E,"TRAINING"); if trn then add("LOW","training state reacts to "..c.text.." → "..trn.text) end
        local tool=has(E,"TOOL"); if tool then add("LOW","tool change after "..c.text.." → "..tool.text) end
    end
    for _,a in ipairs(TR.ambient) do
        local qd=has(a.effects,"DATA_CHANGED","data:quests") or has(a.effects,"DATA_ADDED","data:quests")
        local qt=has(a.effects,"TEXT","zquestsframe") or has(a.effects,"GUI_ADDED","zquestsframe")
        local died=has(a.effects,"NPC_DIED")
        if (qd or qt) and died then
            add("HIGH","quest objective progressed after NPC death: "..died.text.." → "..((qd or qt).text))
        elseif (qd or qt) and has(a.effects,"NPC_DESPAWN") then
            add("LOW","quest progress after NPC despawn: "..((qd or qt).text))
        end
    end
    -- Strong temporal correlation independent of ambient slicing/action groups:
    -- an NPC_DIED followed shortly by quest GUI/data change is objective-progress evidence.
    for i,e in ipairs(TR.events) do
        if e.kind=="NPC_DIED" then
            for j=i+1,#TR.events do
                local q=TR.events[j]; local dt=q.t-e.t
                if dt>4 then break end
                local low=string.lower(q.text or "")
                local questChange=(q.kind=="DATA_CHANGED" or q.kind=="DATA_ADDED" or q.kind=="DATA_REMOVED") and string.find(low,"data:quests",1,true)
                    or (q.kind=="TEXT" or q.kind=="GUI_ADDED" or q.kind=="GUI_REMOVED") and string.find(low,"zquestsframe",1,true)
                if questChange then
                    add("HIGH","quest objective progressed after NPC death: "..e.text.." → "..q.text)
                    break
                end
            end
        end
    end
    -- active-slot evidence: which local slot changed while playing (only when the slot is unresolved)
    local perSlot={}
    for _,e in ipairs(TR.events) do local sl=string.match(e.text,"^DATA%[([^%]]+)%]:"); if sl then perSlot[sl]=(perSlot[sl] or 0)+1 end end
    for sl,n in pairs(perSlot) do add(n>=3 and "MEDIUM" or "LOW","active slot evidence: "..sl.." changed "..n.."× during play (resolver: "..tostring(SCH and SCH.slot and SCH.slot.status)..")") end
    TR.candidates=C
    return C
end

-- ---------- control ----------
function RAVYN:StartLearning()
    if TR.active then return result(false,"ALREADY_LEARNING") end
    TR.seq=TR.seq+1; TR.active=true; TR.startedAt=os.clock(); TR.clock=os.date("%H:%M:%S")
    TR.events={}; TR.groups={}; TR.ambient={}; TR.candidates={}
    TR.saved=false; TR.cancelled=nil; TR.hooksUsed=0
    local ok,err=pcall(startHooks)
    if not ok then stopHooks(); TR.active=false; return result(false,"TRACE_HOOK_FAILED",tostring(err)) end
    RAVYN.Logger:log("INFO","UNIVERSAL_TRACE_START",{hooks=TR.hookCount})
    return result(true,"LEARNING",{hooks=TR.hookCount})
end
local function report()
    local L={string.format("UNIVERSAL TRACE #%03d · %s · %.0fs · %d events · %d action groups · %d hooks",TR.seq,TR.clock,os.clock()-TR.startedAt,#TR.events,#TR.groups,TR.hooksUsed or 0),
        "status: CANDIDATES ONLY — nothing is verified automatically",""}
    table.insert(L,"CANDIDATE SEMANTICS")
    for _,c in ipairs(TR.candidates) do table.insert(L,"  ["..c.confidence.."] "..c.text) end
    if #TR.candidates==0 then table.insert(L,"  none inferred") end
    table.insert(L,""); table.insert(L,"ACTION → EFFECTS")
    for _,g in ipairs(TR.groups) do
        if #g.effects>0 then
            table.insert(L,string.format("+%.1fs %s %s",g.cause.t,g.cause.kind,g.cause.text))
            for i,e in ipairs(g.effects) do if i>25 then table.insert(L,"      … "..(#g.effects-25).." more"); break end; table.insert(L,string.format("      +%.1fs %s %s",e.t,e.kind,e.text)) end
        end
    end
    table.insert(L,""); table.insert(L,"AMBIENT (no user action)")
    for _,a in ipairs(TR.ambient) do
        local interesting={}
        for _,e in ipairs(a.effects) do if e.kind~="MARKER_ADDED" and e.kind~="MARKER_REMOVED" then table.insert(interesting,e) end end
        for i,e in ipairs(interesting) do if i>12 then break end; table.insert(L,string.format("  +%.1fs %s %s",e.t,e.kind,e.text)) end
    end
    return table.concat(L,"\n")
end
function RAVYN:StopLearning()
    if not TR.active then return result(false,"NOT_LEARNING") end
    stopHooks(); TR.active=false
    infer()
    TR.last=report()
    local FR=RAVYN.FeatureRegistry; if FR and FR.applyTrace then pcall(FR.applyTrace,TR.candidates) end
    local wf=(getgenv and getgenv().writefile) or G.writefile
    if type(wf)=="function" then pcall(function()
        local mf=(getgenv and getgenv().makefolder) or G.makefolder; local isf=(getgenv and getgenv().isfolder) or G.isfolder
        if mf and isf and not isf("RAVYN") then mf("RAVYN") end
        if mf and isf and not isf("RAVYN/Traces") then mf("RAVYN/Traces") end
        wf("RAVYN/Traces/"..os.date("%Y%m%d_%H%M%S").."_"..string.format("%03d",TR.seq).."_trace.txt",TR.last)
        TR.saved=true
    end) end
    RAVYN.Logger:log("INFO","UNIVERSAL_TRACE_STOP",{events=#TR.events,candidates=#TR.candidates})
    return result(true,"TRACE_COMPLETE",{events=#TR.events,groups=#TR.groups,candidates=#TR.candidates})
end
function RAVYN:CopyTraceReport()
    local f=(getgenv and getgenv().setclipboard) or G.setclipboard
    if not TR.last then return result(false,"NO_TRACE") end
    if type(f)~="function" then return result(false,"SETCLIPBOARD_UNAVAILABLE") end
    pcall(f,TR.last); return result(true,"TRACE_COPIED")
end
-- Stop Everything / Destroy cancel an in-progress trace; partial traces are not saved as evidence
local baseStop=RAVYN.Stop
function RAVYN:Stop() if TR.active then stopHooks(); TR.active=false; TR.cancelled=os.clock() end; return baseStop(self) end
local baseDestroy=RAVYN.Destroy
function RAVYN:Destroy() if TR.active then stopHooks(); TR.active=false end; return baseDestroy(self) end
CTX["TR391"]=TR
RAVYN.Logger:log("INFO","UNIVERSAL_TRACE_V391_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("FeatureRegistryV391.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
-- v3.9.1.1 FeatureRegistry: IDENTITY · PRESENCE · ACTION · VERIFY are SEPARATE.
-- IDENTITY: the system exists in static runtime content (Ouwland.Content, QuestStates, dialogues, regions, player data).
-- PRESENCE: an instance is streamed in the world right now (as of the last explicit refresh). Never lowers identity.
-- ACTION / VERIFY: implemented path or UniversalTrace CANDIDATE — never auto-VERIFIED.
local SCH=CTX["SCH391"]
local FR={features={},order={},refreshedAt=nil}
RAVYN.FeatureRegistry=FR
local function feat(key,title,keys,identityFn,presenceFn,action,verify,note)
    FR.features[key]={key=key,title=title,keys=keys,identityFn=identityFn,presenceFn=presenceFn,
        identity="UNRESOLVED",presence="N/A",action=action or "UNRESOLVED",verify=verify or "UNRESOLVED",note=note}
    table.insert(FR.order,key)
end
local function I() return SCH.get().identities end
local function qsHas(word) for _,n in ipairs(I().questStates or {}) do if string.find(string.lower(n),word,1,true) then return "QuestStates."..n end end; return nil end
local function content(name) return (I().contentIdentity or {})[name] end
local function present(name) local f=(I().world or {})[name]; return f and f.path or nil end
local function sec(name) for _,n in ipairs(I().playerDataSections or {}) do if n==name then return "slot."..n end end; return nil end
local function idOf(ev) if ev then return "VERIFIED",ev end; return "NOT_FOUND_IN_CONTEXT",nil end
local function presOf(...)
    if not SCH.fullAt then return "NOT_CHECKED",nil end
    for _,n in ipairs({...}) do local p=present(n); if p then return "PRESENT",p end end
    return "NOT_STREAMED",nil
end
local function na() return "N/A",nil end
local function any(...) for _,v in ipairs({...}) do if v then return v end end; return nil end

feat("CROW","Crow (Boss Hunts)",{"hunt"},function() local x=I(); return idOf(x.crowBossHuntsFound and ("Boss Hunts dialogues "..#x.crowBossHuntDialogues.." · npcs "..#x.crowBossHuntNpcs) or nil) end,na)
feat("MUZAN","Muzan",{"muzan"},function()
    local x=I(); local ev=(x.muzanQuestState and "QuestStates.Muzan Quest" or "")..(x.muzanDialogue.actions and " · MuzanActions" or "")..(x.muzanDialogue.quests and " · Dialogues.Quests.Muzan" or "")
    return idOf(ev~="" and ev or nil) end,function() return presOf("Muzan") end,nil,nil,"transformation and repeatable tasks are separate flows")
feat("QUESTS","Generic quests",{"quest"},function() local n=#(I().questStates or {}); return idOf((n>0 or sec("Quests")) and (n.." QuestStates"..(sec("Quests") and " · slot Quests" or "")) or nil) end,na,
    "PARTIAL","PARTIAL","action: prompt + dialogue · verify: GUI signature + slot data cross-check")
feat("BREATHING","Breathing trainers",{"trainer","breath"},function()
    local n=0
    for _,t in ipairs({"Flame","Thunder","Water","Wind","Stone","Serpent","Insect","Sound"}) do if content(t.." Trainer") then n=n+1 end end
    return idOf(n>0 and (n.." of 8 trainer identities in Ouwland.Content") or nil) end,
    function()
        if not SCH.fullAt then return "NOT_CHECKED",nil end
        local n=0; for _,f in pairs(I().trainers or {}) do if f then n=n+1 end end
        return n>0 and "PRESENT" or "NOT_STREAMED",n>0 and (n.." streamed") or nil end)
feat("TRAINING","Training stations",{"training","push","boulder","parkour","meditat","cup","aim","squat"},function() local s=I().trainingStations or {}; return idOf(#s>0 and ("Workspace.Training: "..#s.." entries") or nil) end,na)
feat("FINAL_SELECTION","Final Selection",{"final selection"},function()
    local x=I(); return idOf(any(x.finalSelectionRegion and ("region "..x.finalSelectionRegion) or nil,qsHas("final"),(x.finalSelectionWorld and x.finalSelectionWorld[1]) and ("world "..x.finalSelectionWorld[1]) or nil)) end,
    function() local w=I().finalSelectionWorld; if not SCH.fullAt then return "NOT_CHECKED",nil end; return (w and #w>0) and "PRESENT" or "NOT_STREAMED",w and w[1] end)
feat("OUWIGAHARA","Ouwigahara",{"ouwi","card","dungeon"},function() local n=SCH.get().nodes; return n.ouwlandContent and "PARTIAL" or "NOT_FOUND_IN_CONTEXT",n.ouwlandContent and "Ouwland.Content present; cards not found" or nil end,na)
feat("FISHING","Fishing",{"fish"},function() return idOf(qsHas("fishing")) end,na)
feat("ESCORT","Escort",{"escort","akio"},function() return idOf(qsHas("escort")) end,na)
feat("SEALED_CHESTS","Sealed chests",{"sealed chest"},function() return idOf(any(content("Sealed Chest T1"),content("Sealed Chest T2"),content("Sealed Chest T3"))) end,
    function() return presOf("Sealed Chest T1","Sealed Chest T2","Sealed Chest T3") end)
feat("SOULS","Souls (Harvester)",{"soul"},function() return idOf(content("Harvester of Souls Zurinyz")) end,function() return presOf("Harvester of Souls Zurinyz") end)
feat("YETI","Yeti",{"yeti"},function() return idOf(content("Yeti Summon")) end,function() return presOf("Yeti Summon") end)
feat("BLACK_MARKETER","Black Marketer",{"black marketer"},function() return idOf(content("Black Marketer")) end,function() return presOf("Black Marketer") end)
feat("SHOPS","Shops / merchants",{"merchant","shop","buy","purchase"},function() return idOf(I().merchantActions and "Dialogues.Functions.MerchantActions" or nil) end,na)
feat("REFINE","Refine",{"refin"},function() return idOf(content("Refiner Hagane")) end,function() return presOf("Refiner Hagane") end)
feat("SKILL_TREE","Skill tree",{"skilltree","skill tree"},function() return idOf(sec("SkillTreeUnlockedList")) end,na)
feat("MASTERY","Mastery",{"mastery"},function() return idOf(sec("MasteryProgressionList")) end,na)
feat("CLAN","Clan",{"clan"},function()
    local ev=sec("Clan"); if ev then return "VERIFIED",ev end
    for _,c in ipairs(I().ociCommands or {}) do if string.find(string.lower(c),"clan",1,true) then return "CANDIDATE","command module name only (never invoked)" end end
    return "NOT_FOUND_IN_CONTEXT",nil end,na)
feat("EQUIPMENT","Equipment / loadouts",{"loadout","equip","inventory"},function() return idOf(sec("ItemLoadouts") or sec("Inventory")) end,na)
feat("ESP","ESP",{},function() return "LOCAL","RAVYN-drawn overlay" end,na,"PARTIAL","N/A","local rendering, no game binding")
feat("POSITION","Position toolkit",{},function() return "LOCAL","RAVYN saved places" end,na,"PARTIAL","N/A","local, no game binding")

-- explicit refresh only (no continuous world polling). full=true also re-checks presence.
function FR.refresh(full)
    pcall(SCH.build,full==true)
    for _,k in ipairs(FR.order) do
        local f=FR.features[k]
        local ok,st,ev=pcall(f.identityFn); f.identity=ok and st or "UNRESOLVED"; f.identityEvidence=ok and ev or tostring(st)
        local okP,pst,pev=pcall(f.presenceFn)
        -- presence never lowers identity; it only reports what is streamed now
        f.presence=okP and pst or "UNRESOLVED"; f.presenceEvidence=okP and pev or nil
    end
    local mz=FR.features.MUZAN; local wm=(I().world or {}).Muzan
    if wm and wm.inst and wm.inst:FindFirstChildWhichIsA("ProximityPrompt",true) and mz.action=="UNRESOLVED" then mz.action="CANDIDATE"; mz.actionEvidence="world Muzan ProximityPrompt present" end
    FR.refreshedAt=os.clock(); FR.presenceAt=full and os.clock() or FR.presenceAt
end
-- UniversalTrace candidates → ACTION / VERIFY candidates (never VERIFIED)
function FR.applyTrace(candidates)
    for _,c in ipairs(candidates or {}) do
        local t=string.lower(c.text)
        for _,k in ipairs(FR.order) do
            local f=FR.features[k]
            for _,w in ipairs(f.keys) do
                if string.find(t,w,1,true) then
                    if f.action=="UNRESOLVED" or f.action=="CANDIDATE" then f.action="CANDIDATE"; f.actionEvidence="["..c.confidence.."] "..c.text end
                    if (string.find(t,"data:",1,true) or string.find(t,"zquestsframe",1,true)) and (f.verify=="UNRESOLVED" or f.verify=="CANDIDATE") then
                        f.verify="CANDIDATE"; f.verifyEvidence="["..c.confidence.."] "..c.text end
                    break
                end
            end
        end
    end
end
function RAVYN:GetFeatureRegistryReport()
    FR.refresh(true)
    local L={"FEATURE REGISTRY · IDENTITY / PRESENCE / ACTION / VERIFY are separate · nothing auto-VERIFIED",
        "presence checked now (explicit refresh); NOT_STREAMED never lowers identity",""}
    for _,k in ipairs(FR.order) do
        local f=FR.features[k]
        table.insert(L,string.format("%-22s identity %-20s presence %-13s action %-11s verify %s",f.title,f.identity,f.presence,f.action,f.verify))
        for _,x in ipairs({{"identity",f.identityEvidence},{"presence",f.presenceEvidence},{"action",f.actionEvidence},{"verify",f.verifyEvidence},{"note",f.note}}) do
            if x[2] then table.insert(L,"      "..x[1]..": "..tostring(x[2])) end
        end
    end
    table.insert(L,""); table.insert(L,"Not yet found in this context (not claimed absent): Gourds, Spider Lilies, Ouwigahara cards, Forge.")
    return result(true,"FEATURE_REGISTRY",table.concat(L,"\n"))
end
function RAVYN:CopyDiscoveryReport()
    local f=(getgenv and getgenv().setclipboard) or G.setclipboard
    local b=self:GetFeatureRegistryReport(); local a=self:GetRuntimeSchemaReport()
    local text=a.value.."\n\n"..b.value
    if type(f)~="function" then return result(false,"SETCLIPBOARD_UNAVAILABLE",text) end
    pcall(f,text); return result(true,"DISCOVERY_REPORT_COPIED")
end
CTX["FR391"]=FR
RAVYN.Logger:log("INFO","FEATURE_REGISTRY_V3911_READY")
return true]==========]); if not ok then return end end

do local ok=runChunk("CrowControllerV393.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Util=CTX["Util"]
local Config=CTX["Config"]
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local requestTravel=CTX["requestTravel384"]
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local LP=Players.LocalPlayer
local VIM=game:GetService("VirtualInputManager")

-- v3.9.3 Direct Crow controller.
-- Evidence reviewed from two live UniversalTrace captures:
--   toolbar slot 5 -> Kasugai Crow mission GUI
--   Hunt5.Claim  -> DATA:Quests.Holder.Eliminate Datai within ~0.1 s
--   Hunt10.Claim -> DATA:Quests.Holder.Eliminate Enru within ~0.1 s
-- This controller uses those GUI/data bindings only. No ModuleScript require(), no game remote calls.

local defaults={
    Enabled=false,
    PreferNearest=true,
    TickInterval=.35,
    OpenCooldown=2.5,
    AcceptCooldown=1.0,
    AcceptVerifyTimeout=3.0,
    MenuWait=4.5,
    TargetArrivalHeight=5.5,
    ReTeleportDistance=80,
}
Config.Default.CrowDirect=Util.deepCopy(defaults)
RAVYN.Config.CrowDirect=Util.deepMerge(defaults,RAVYN.Config.CrowDirect or {})
local function cfg() return RAVYN.Config.CrowDirect end
local CD={
    status="READY", detail="",
    missionsSeen=0, accepted=0, completed=0,
    lastOpenAt=-math.huge,lastAcceptAt=-math.huge,lastTravelAt=-math.huge,
    pending=nil,lastQuestId=nil,lastQuestTarget=nil,lastTarget=nil,lastCenter=nil,
    waitUntil=0,dailyCurrent=nil,dailyMax=nil,dailyComplete=false,
    centerCache={},savedAutoQuestSources=nil,events={},
}
RAVYN.CrowDirect=CD

local function low(v) return string.lower(tostring(v or "")) end
local function trim(v)
    v=tostring(v or ""):gsub("<.->",""):gsub("^%s+",""):gsub("%s+$","")
    return v
end
local function log(text,kind)
    CD.detail=tostring(text or "")
    table.insert(CD.events,{at=os.clock(),text=CD.detail,kind=kind or "info"})
    while #CD.events>20 do table.remove(CD.events,1) end
    if RAVYN.Logger then RAVYN.Logger:log("INFO","CROW · "..CD.detail,{kind=kind}) end
end
local function setStatus(s,d)
    if CD.status~=s then CD.status=s; if d then log(d) end elseif d then CD.detail=d end
end
local function getPG() return LP and LP:FindFirstChildOfClass("PlayerGui") end
local function rootPart()
    local r=RAVYN.ReadAdapter and RAVYN.ReadAdapter:getRootPart() or nil
    return r and r.ok and r.value or nil
end
local function goWants()
    if cfg().Enabled==true then return true end
    local GO=RAVYN.GoState
    return GO and GO.active and not GO.paused and (GO.goal=="AUTO_PROGRESS" or GO.goal=="QUESTS")
end
local function running()
    return goWants() and RAVYN.FSM and RAVYN.FSM.state=="RUNNING"
end
local function clickCenter(btn)
    if not btn or not btn.Parent or not btn:IsA("GuiButton") then return false,"BUTTON_MISSING" end
    local visible=true
    local cur=btn
    while cur and cur:IsA("GuiObject") do
        if cur.Visible==false then visible=false; break end
        cur=cur.Parent
    end
    if not visible then return false,"BUTTON_HIDDEN" end
    local p,s=btn.AbsolutePosition,btn.AbsoluteSize
    if s.X<2 or s.Y<2 then return false,"BUTTON_ZERO_SIZE" end
    local x=math.floor(p.X+s.X*.5); local y=math.floor(p.Y+s.Y*.5)
    local IA=RAVYN.InputAudit; if IA and IA.note then IA.note("MOUSE","crow "..tostring(btn.Name),"CROW") end
    local ok,err=pcall(function()
        VIM:SendMouseButtonEvent(x,y,0,true,game,0)
        task.wait(.025)
        VIM:SendMouseButtonEvent(x,y,0,false,game,0)
    end)
    return ok,ok and "CLICKED" or tostring(err)
end
local function toolbarCrowButton()
    local pg=getPG(); if not pg then return nil end
    local c=pg:FindFirstChild("ComponentsHolder")
    local b=c and c:FindFirstChild("BottomHolder")
    local t=b and b:FindFirstChild("Toolbar")
    local s=t and t:FindFirstChild("SkillHolder")
    local btn=s and s:FindFirstChild("5_ToolPosition")
    return btn and btn:IsA("GuiButton") and btn or nil
end
local function crowMenu()
    local pg=getPG(); if not pg then return nil end
    local c=pg:FindFirstChild("ComponentsHolder"); if not c then return nil end
    local frame=c:FindFirstChild("DialogueFrame")
    local npc=frame and frame:FindFirstChild("NpcName",true)
    if not (npc and string.find(low(npc.Text),"kasugai crow",1,true)) then return nil end
    local dc=c:FindFirstChild("DialogueContent")
    local inner=dc and dc:FindFirstChild("InnerHolder",true)
    if not inner then return nil end
    return {frame=frame,content=dc,inner=inner,npc=npc}
end
local function footerInfo(menu)
    local current,maxn,seconds=nil,nil,nil
    if not menu or not menu.content then return current,maxn,seconds end
    for _,d in ipairs(menu.content:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local text=trim(d.Text)
            local a,b=string.match(text,"(%d+)%s*/%s*(%d+)")
            if a and b then current,maxn=tonumber(a),tonumber(b) end
            local sec=string.match(low(text),"next mission in.-(%d+)%s*s")
            if sec then seconds=tonumber(sec) end
        end
    end
    return current,maxn,seconds
end
local function findValue(parent,name)
    local x=parent and parent:FindFirstChild(name)
    if x and x:IsA("ValueBase") then return x.Value end
    return nil
end
local function activeQuest()
    local SCH=RAVYN.RuntimeSchema
    local root=SCH and SCH.get and SCH.get().nodes.sectionRoot
    local quests=root and root:FindFirstChild("Quests")
    local holder=quests and quests:FindFirstChild("Holder")
    if holder then
        local list=holder:GetChildren()
        table.sort(list,function(a,b) return a.Name<b.Name end)
        for _,q in ipairs(list) do
            local target=nil; local progress=nil; local required=nil
            local tasks=q:FindFirstChild("Tasks")
            if tasks then
                for _,t in ipairs(tasks:GetChildren()) do
                    local code=findValue(t,"Code")
                    if code~=nil and tostring(code)~="" then target=tostring(code) end
                    local v=findValue(t,"Value"); local m=findValue(t,"Max")
                    if type(v)=="number" then progress=v end
                    if type(m)=="number" then required=m end
                    if target then break end
                end
            end
            local qs=findValue(q,"QuestString")
            if not target then
                local text=trim(qs or q.Name)
                target=string.match(text,"[Dd]efeat%s+(.+)") or string.match(text,"[Ee]liminate%s+(.+)")
            end
            return {id=q:GetFullName(),name=q.Name,target=trim(target),progress=progress,required=required,inst=q}
        end
    end
    -- GUI fallback if slot data is temporarily unavailable.
    local pg=getPG(); local c=pg and pg:FindFirstChild("ComponentsHolder"); local l=c and c:FindFirstChild("LeftCenterFramesHolder")
    local z=l and l:FindFirstChild("zQuestsFrame")
    if z then
        local joined={}
        for _,d in ipairs(z:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local t=trim(d.Text); if t~="" then table.insert(joined,t) end
            end
        end
        local all=table.concat(joined," | ")
        local target=string.match(all,"Defeat%s+([%w%s%-_]+)%s+%d+/%d+") or string.match(all,"Eliminate%s+([%w%s%-_]+)%s+%d+/%d+")
        if target then
            local a,b=string.match(all,"(%d+)%s*/%s*(%d+)")
            return {id="GUI:"..trim(target),name="GUI Quest",target=trim(target),progress=tonumber(a),required=tonumber(b),gui=true}
        end
    end
    return nil
end
local function vecFromInstance(inst)
    if not inst then return nil end
    local attrs=inst:GetAttributes()
    for _,k in ipairs({"Center","Position","SpawnPosition","Spawn","Location"}) do
        if typeof(attrs[k])=="Vector3" then return attrs[k] end
    end
    for _,k in ipairs({"Center","Position","SpawnPosition","Spawn","Location"}) do
        local v=inst:FindFirstChild(k)
        if v and v:IsA("Vector3Value") then return v.Value end
    end
    return nil
end
-- v1.1: snapshot positions are {x,y,z} tables; every destination is normalised to Vector3 before arithmetic.
local function toV3(p)
    if typeof(p)=="Vector3" then return p end
    if type(p)=="table" and type(p.x)=="number" and type(p.y)=="number" and type(p.z)=="number" then return Vector3.new(p.x,p.y,p.z) end
    return nil
end
CD.toV3=toV3
local function resolveCenter(target)
    target=trim(target); if target=="" then return nil end
    -- 1) streamed runtime entity: always the LIVE position (never cached, so a wandering boss is never chased to a stale spot)
    for _,e in ipairs((RAVYN.Features and RAVYN.Features.snapshot and RAVYN.Features.snapshot.npcs) or {}) do
        if e and e.name==target and e.position and e.alive~=false then local v=toV3(e.position); if v then return v end end
    end
    local cached=CD.centerCache[target]
    if cached then return cached end
    -- 2) remembered live boss position (not cached: it updates whenever the boss is seen again).
    local bm=RAVYN.BossMeta and RAVYN.BossMeta.byName and RAVYN.BossMeta.byName[target]
    if bm and bm.lastPos then local v=toV3(bm.lastPos); if v then return v end end
    -- 3) static replicated Boss Hunts content. Read attributes/ValueBases only; never require modules.
    -- Prefer the small Boss Hunts subtree; only fall back to a bounded Ouwland scan if the schema moves.
    local SCH=RAVYN.RuntimeSchema
    local sn=SCH and SCH.get and SCH.get().nodes.npcs
    local bossHunts=sn and sn:FindFirstChild("Boss Hunts")
    local content=RS:FindFirstChild("Ouwland") and RS.Ouwland:FindFirstChild("Content")
    local roots={}
    if bossHunts then table.insert(roots,{inst=bossHunts,limit=1200}) end
    if content then table.insert(roots,{inst=content,limit=3000}) end
    for _,rec in ipairs(roots) do
        local count=0
        for _,d in ipairs(rec.inst:GetDescendants()) do
            count=count+1; if count>rec.limit then break end
            local npcCode=d:GetAttribute("NpcCode")
            if d.Name==target or tostring(npcCode or "")==target then
                local p=vecFromInstance(d)
                if not p then
                    local cur=d.Parent
                    for _=1,4 do if not cur then break end; p=vecFromInstance(cur); if p then break end; cur=cur.Parent end
                end
                if not p then
                    for i,x in ipairs(d:GetDescendants()) do
                        if i>100 then break end
                        p=vecFromInstance(x); if p then break end
                    end
                end
                if p then CD.centerCache[target]=p; return p end
            end
        end
    end
    return nil
end
local function missionRows(menu)
    local out={}
    if not menu then return out end
    for _,row in ipairs(menu.inner:GetChildren()) do
        if string.match(row.Name,"^Hunt%d+") then
            local claim=row:FindFirstChild("Claim",true)
            local questText=nil
            for _,d in ipairs(row:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    local t=trim(d.Text)
                    if string.find(low(t),"defeat ",1,true) then questText=t; break end
                end
            end
            local target=questText and trim(string.match(questText,"[Dd]efeat%s+(.+)") or "") or ""
            if claim and claim:IsA("GuiButton") and target~="" then
                table.insert(out,{row=row,claim=claim,quest=questText,target=target})
            end
        end
    end
    CD.missionsSeen=#out
    return out
end
local function scoreMission(m)
    local root=rootPart()
    local streamed=false; local pos=nil
    for _,e in ipairs((RAVYN.Features and RAVYN.Features.snapshot and RAVYN.Features.snapshot.npcs) or {}) do
        if e and e.name==m.target and e.alive~=false then streamed=true; pos=e.position; break end
    end
    pos=pos or resolveCenter(m.target)
    local d=(root and pos) and (root.Position-pos).Magnitude or math.huge
    m.center=pos; m.distance=d
    return (streamed and 1000000 or 0) + (pos and 100000 or 0) - math.min(d,99999)
end
local function chooseMission(menu)
    local rows=missionRows(menu); local best,bestScore=nil,-math.huge
    for _,m in ipairs(rows) do
        local s=scoreMission(m)
        if not cfg().PreferNearest then s=0-tonumber(string.match(m.row.Name,"%d+") or 999) end
        if s>bestScore then best,bestScore=m,s end
    end
    return best
end
local function suppressGeneric(v)
    local ai=RAVYN.Config.AdaptiveIntel
    if not ai then return end
    if v then
        if CD.savedAutoQuestSources==nil then CD.savedAutoQuestSources=ai.AutoQuestSources end
        ai.AutoQuestSources=false
    elseif CD.savedAutoQuestSources~=nil then
        ai.AutoQuestSources=CD.savedAutoQuestSources; CD.savedAutoQuestSources=nil
    end
end
CD.resolveCenter=resolveCenter
local function travelTarget(target)
    -- v1.1: objective travel has ONE authority (DirectCore). Crow only reports the result.
    local D=RAVYN.Direct
    if D and D.travelToObjective then
        local okD,okT,why=pcall(D.travelToObjective,target,"CROW")
        if okD then local p=resolveCenter(target); if p then CD.lastCenter=p end; return okT,why end
    end
    local pos=resolveCenter(target)
    if not pos or not requestTravel then return false,"TARGET_CENTER_UNRESOLVED" end
    local root=rootPart(); local d=root and (root.Position-pos).Magnitude or math.huge
    CD.lastCenter=pos
    if d<=(cfg().ReTeleportDistance or 80) then return true,"NEAR_TARGET" end
    local y=(RAVYN.Config.TravelController and RAVYN.Config.TravelController.ArriveHeight) or cfg().TargetArrivalHeight or 5.5
    CD.lastTravelAt=os.clock()
    local r=requestTravel(pos+Vector3.new(0,y,0),"CROW "..target,"crow:"..target,.8)
    return r and r.ok~=false,r and r.code or "TRAVEL_SENT"
end
local function openCrow(now)
    local menu=crowMenu()
    if menu then return menu end
    if now-CD.lastOpenAt<(cfg().OpenCooldown or 2.5) then return nil end
    if RAVYN.LootController and RAVYN.LootController.active then setStatus("WAITING_LOOT","Boss loot has priority"); return nil end
    if CTX["LiveAction"] and CTX["LiveAction"].target then setStatus("WAITING_COMBAT","Waiting for current fight to finish"); return nil end
    local btn=toolbarCrowButton()
    if not btn then setStatus("CROW_TOOL_NOT_FOUND","Toolbar slot 5 is not available"); return nil end
    CD.lastOpenAt=now
    local ok,why=clickCenter(btn)
    setStatus(ok and "OPENING_CROW" or "OPEN_FAILED",ok and "Opening Kasugai Crow" or why)
    return nil
end
local function acceptFromMenu(menu,now)
    local current,maxn,seconds=footerInfo(menu)
    CD.dailyCurrent,CD.dailyMax=current,maxn
    if current and maxn and current>=maxn then
        CD.dailyComplete=true; suppressGeneric(false); setStatus("DAILY_COMPLETE",string.format("Crow missions %d/%d complete",current,maxn)); return
    end
    if seconds and seconds>0 then
        CD.waitUntil=math.max(CD.waitUntil,now+seconds+.25)
        setStatus("COOLDOWN","Next Crow mission in "..seconds.."s"); return
    end
    if now-CD.lastAcceptAt<(cfg().AcceptCooldown or 1) then return end
    local m=chooseMission(menu)
    if not m then setStatus("NO_HUNT_AVAILABLE","Crow menu open, no claimable Hunt row yet"); return end
    CD.lastAcceptAt=now
    local before=activeQuest()
    local ok,why=clickCenter(m.claim)
    if ok then
        CD.pending={target=m.target,quest=m.quest,at=now,before=before and before.id or nil,center=m.center}
        setStatus("ACCEPTING","Claiming "..m.quest)
    else setStatus("ACCEPT_FAILED",why) end
end
local function tick()
    if not running() then
        suppressGeneric(false)
        if CD.status~="READY" and CD.status~="STOPPED" then setStatus("READY","Waiting for RAVYN GO") end
        return
    end
    local now=os.clock()
    local q=activeQuest()
    if q then
        suppressGeneric(false)
        if CD.pending then
            local same=(q.target==CD.pending.target) or (q.id~=CD.pending.before)
            if same then
                CD.accepted=CD.accepted+1
                log("Mission accepted · "..tostring(q.target),"success")
                CD.pending=nil
            elseif now-CD.pending.at>(cfg().AcceptVerifyTimeout or 3) then
                log("Claim click did not create the expected quest","warn"); CD.pending=nil; CD.waitUntil=now+2
            end
        end
        if CD.lastQuestId and q.id~=CD.lastQuestId then CD.completed=CD.completed+1 end
        CD.lastQuestId=q.id; CD.lastQuestTarget=q.target; CD.lastTarget=q.target
        if q.target and q.target~="" then
            local ok,why=travelTarget(q.target)
            setStatus(ok and "ACTIVE" or "TARGET_UNRESOLVED",
                string.format("%s%s%s",q.target,q.progress and (" · "..q.progress.."/"..tostring(q.required or "?")) or "",ok and "" or (" · "..why)))
        else setStatus("ACTIVE","Crow quest active") end
        return
    end
    -- no quest: if one existed previously, completion/expiry is observed from local quest data disappearing.
    if CD.lastQuestId then
        CD.completed=CD.completed+1
        log("Quest left active data · ready for next Crow mission","success")
        CD.lastQuestId=nil; CD.lastQuestTarget=nil; CD.lastTarget=nil
        CD.waitUntil=math.max(CD.waitUntil,now+1)
    end
    if CD.pending then
        if now-CD.pending.at>(cfg().AcceptVerifyTimeout or 3) then
            log("Crow claim verification timed out","warn"); CD.pending=nil; CD.waitUntil=now+2
        else setStatus("VERIFYING_ACCEPT","Waiting for quest data"); return end
    end
    if CD.dailyComplete then suppressGeneric(false); return end
    if now<CD.waitUntil then suppressGeneric(true); setStatus("COOLDOWN",string.format("Crow wait %.0fs",math.max(0,CD.waitUntil-now))); return end
    suppressGeneric(true)
    local menu=crowMenu()
    if not menu then openCrow(now); return end
    setStatus("READING_HUNTS","Kasugai Crow mission list")
    acceptFromMenu(menu,now)
end

function RAVYN:GetCrowDirectStatus()
    return result(true,"CROW_DIRECT_STATUS",{
        status=CD.status,detail=CD.detail,missionsSeen=CD.missionsSeen,accepted=CD.accepted,completed=CD.completed,
        target=CD.lastTarget,dailyCurrent=CD.dailyCurrent,dailyMax=CD.dailyMax,dailyComplete=CD.dailyComplete,
        wait=math.max(0,(CD.waitUntil or 0)-os.clock()),center=CD.lastCenter,
    })
end
function RAVYN:ResetCrowDaily()
    CD.dailyComplete=false; CD.dailyCurrent=nil; CD.dailyMax=nil; CD.waitUntil=0
    return result(true,"CROW_RESET")
end

-- Human-reviewed live evidence: promote only the parts actually established.
local GK=RAVYN.GameKnowledge
if GK and GK.capabilities and GK.capabilities.CROW_MISSION then
    local c=GK.capabilities.CROW_MISSION
    c.status="PARTIAL"
    c.evidence="Live traces #002/#004: toolbar slot 5 opened Kasugai Crow; Hunt5.Claim→Eliminate Datai and Hunt10.Claim→Eliminate Enru in local quest data within ~0.1s"
    c.detail="Mission open/claim mapped; completion/loot remains handled by generic quest/combat/loot state"
end
if GK and GK.systems and GK.systems.CROW_MISSION then
    local s=GK.systems.CROW_MISSION
    s.status="PARTIAL"
    s.start="LIVE: toolbar SkillHolder.5_ToolPosition opens Kasugai Crow; Hunt*.Claim creates local quest data"
    s.startVerify="LIVE: DATA:Quests.Holder.Eliminate <target> + zQuestsFrame"
    s.paths="LIVE: ComponentsHolder.DialogueContent...InnerHolder.Hunt*.Claim · local slot Quests.Holder"
    s.unknown="explicit completion/turn-in semantics; controller treats quest disappearance as completion and reopens Crow"
end
local FR=RAVYN.FeatureRegistry
if FR and FR.features and FR.features.CROW then
    FR.features.CROW.action="PARTIAL"
    FR.features.CROW.actionEvidence="Two reviewed live claims: Hunt5→Datai, Hunt10→Enru"
    FR.features.CROW.verify="PARTIAL"
    FR.features.CROW.verifyEvidence="Claim produced local quest data + quest GUI"
end

-- lightweight controller loop; no Workspace polling and no UniversalTrace hooks.
local token=0
local function startLoop()
    token=token+1; local mine=token
    task.spawn(function()
        while token==mine and RAVYN and not RAVYN._destroyed do
            local ok,err=pcall(tick)
            if not ok and RAVYN.Logger then RAVYN.Logger:log("WARN","CROW_DIRECT_TICK",{error=tostring(err)}) end
            task.wait(cfg().TickInterval or .35)
        end
    end)
end
startLoop()

local baseStop=RAVYN.Stop
function RAVYN:Stop()
    suppressGeneric(false); CD.pending=nil; CD.waitUntil=0; setStatus("STOPPED","Stopped")
    return baseStop(self)
end
local baseDestroy=RAVYN.Destroy
function RAVYN:Destroy()
    token=token+1; suppressGeneric(false); CD.pending=nil
    return baseDestroy(self)
end
CTX["CrowDirect393"]=CD
RAVYN.Logger:log("INFO","CROW_DIRECT_V393_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("DirectCoreV11.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Util=CTX["Util"]
local Config=CTX["Config"]
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local liveRoot=CTX["liveRoot"]
local requestTravel=CTX["requestTravel384"]
local targetAllowed=CTX["targetAllowed"]
local H=CTX["H"]
-- RAVYN DIRECT v1.1 · DirectCore
-- One authority for: objective (from LOCAL quest data), objective travel, target override, generation tokens,
-- and the lean read path. No remotes, no require(), no other player's data, no hard-coded save slot.
RAVYN.Version="Direct-v1.2.2-silentcombat-hardening"
RAVYN.Build="2026-09-28-direct-v1.2.2"

local defaults={
    FollowQuestData=true,      -- an active local quest objective drives targeting while Auto Play runs
    ObjectiveInterval=.5,      -- local quest data read cadence (few children, no GUI scan)
    ObjectiveArriveHeight=6,
    ObjectiveStreamWait=8,     -- seconds at the last known spot before the objective location is backed off
    ObjectiveTravelBackoff=15,
}
Config.Default.Direct=Util.deepCopy(defaults)
RAVYN.Config.Direct=Util.deepMerge(defaults,RAVYN.Config.Direct or {})
local function dc() return RAVYN.Config.Direct end

local D={objective=nil,state="OFF",detail="",gens={},quests={},questError=nil,lastQuestRead=-math.huge,
    travel={},events={},perf={leanScans=0,fullScans=0},appliedOverride=nil,schemaRebuildAt=-math.huge}
RAVYN.Direct=D

-- ================= generation / session tokens =================
-- kinds: target · respawn · stop · objective · loot · boss · muzan · training · esp
function D.bump(kind) D.gens[kind]=(D.gens[kind] or 0)+1; return D.gens[kind] end
function D.gen(kind) return D.gens[kind] or 0 end
function D.live(kind,tok) return not RAVYN._destroyed and (D.gens[kind] or 0)==tok end
local function event(text,kind)
    table.insert(D.events,{at=os.clock(),text=text,kind=kind or "info"})
    while #D.events>30 do table.remove(D.events,1) end
    if RAVYN.Logger then RAVYN.Logger:log("INFO","QUEST · "..text,{}) end
end
D.event=event

-- ================= shared helpers =================
function D.running() return RAVYN.FSM~=nil and RAVYN.FSM.state=="RUNNING" end
function D.toV3(p)
    if typeof(p)=="Vector3" then return p end
    if type(p)=="table" and type(p.x)=="number" and type(p.y)=="number" and type(p.z)=="number" then return Vector3.new(p.x,p.y,p.z) end
    return nil
end
local toV3=D.toV3
local function lower(v) return string.lower(tostring(v or "")) end
local function trim(v)
    v=tostring(v or ""); v=string.gsub(v,"<.->",""); v=string.gsub(v,"^%s+",""); v=string.gsub(v,"%s+$","")
    return v
end
D.trim=trim
-- nearest streamed, alive entity with this exact name (case-insensitive fallback)
function D.findEntity(name)
    if not name or name=="" then return nil end
    local s=RAVYN.Features and RAVYN.Features.snapshot or {}
    local best,bd=nil,math.huge; local ln=lower(name)
    for _,e in ipairs(s.npcs or {}) do
        if e.position and e.alive~=false and (tonumber(e.health) or 1)>0 and (e.name==name or lower(e.name)==ln) then
            local d=e.distance or math.huge
            if d<bd then best,bd=e,d end
        end
    end
    return best
end
-- Explicit targets (a quest objective you accepted, a boss you selected) are not filtered by the automatic risk
-- rating; NeverAttack and civilian rules still apply. Rules are relaxed only for the duration of the call.
function D.withExplicitRules(fn,...)
    local r=RAVYN.Config.Intelligence and RAVYN.Config.Intelligence.TargetRules
    if not r then return fn(...) end
    local sm,sb=r.RiskMode,r.SkipBossTooStrong
    r.RiskMode="Any"; r.SkipBossTooStrong=false
    local res=table.pack(pcall(fn,...))
    r.RiskMode=sm; r.SkipBossTooStrong=sb
    if not res[1] then error(res[2]) end
    return table.unpack(res,2,res.n)
end
-- common activity vocabulary: OFF · READY · SEARCHING · TRAVELING · FIGHTING · LOOTING · COOLDOWN · UNAVAILABLE
function D.activity(name)
    if not D.running() then return "READY" end
    local LC=RAVYN.LootController; if LC and LC.active then return "LOOTING" end
    local t=LiveAction.target
    if t and (not name or t.name==name) then
        local MO=RAVYN.MoveOwner
        if MO and MO.current=="TRAVEL" then return "TRAVELING" end
        return "FIGHTING"
    end
    local MO=RAVYN.MoveOwner
    if MO and MO.current=="TRAVEL" then return "TRAVELING" end
    return "SEARCHING"
end

-- ================= lean read path (release) =================
-- The v3.4 read scan also walked the whole PlayerGui for quest names, read minimap pins, level/xp and up to 60
-- entity detail structures on every 0.3 s tick. Normal play only needs player + NPC state; the full report stays
-- available in Developer Mode and through "Run live read scan".
local fullRefresh=RAVYN.RefreshReadBindings
function RAVYN:RefreshReadBindings(full)
    if full==true or (self.Config.UI and self.Config.UI.DeveloperMode==true) then
        D.perf.fullScans=D.perf.fullScans+1
        return fullRefresh(self)
    end
    if self._destroyed then return result(false,"DESTROYED") end
    local ok,r=pcall(function()
        local a=self.ReadAdapter
        local health=a:getHealth(); local max=a:getMaxHealth(); local root=a:getRootPart(); local char=a:getCharacter(); local entities=a:getNpcEntities()
        local s={player={health=health.ok and health.value or nil,maxHealth=max.ok and max.value or nil,
            position=root.ok and H.xyz(H.readProp(root.value,"Position")) or nil,characterId=char.ok and H.pathOf(char.value) or nil,
            characterValid=char.ok,rootValid=root.ok},npcs=entities.ok and entities.value or {},mobs={},bosses={}}
        if health.ok and max.ok and max.value>0 then s.player.healthPercent=health.value/max.value*100; s.player.dead=health.value<=0 end
        for _,e in ipairs(s.npcs) do
            if e.classification=="BOSS" then table.insert(s.bosses,e) elseif e.classification=="NORMAL_MOB" then table.insert(s.mobs,e) end
        end
        self.Features.snapshot=s
        D.perf.leanScans=D.perf.leanScans+1; D.snapshotAt=os.clock()
        return result(true,"READ_SCAN_LEAN")
    end)
    if not ok then return result(false,"READ_ERROR",tostring(r)) end
    return r
end
function RAVYN:RunLiveReadScan()
    local r=self:RefreshReadBindings(true); self:_showReport("BINDING REPORT",r); return r
end

-- ================= local quest data (Player_Service.Data.<LocalPlayer>.<active slot>.Quests.Holder) =================
local function val(p,n)
    local x=p and p:FindFirstChild(n)
    if x and x:IsA("ValueBase") then local ok,v=pcall(function() return x.Value end); if ok then return v end end
    return nil
end
local function questHolder(now)
    local SCH=RAVYN.RuntimeSchema
    if not (SCH and SCH.get) then return nil,"SCHEMA_UNAVAILABLE" end
    local s=SCH.get()
    local root=s.nodes and s.nodes.sectionRoot
    if (not root or not root.Parent) and now-D.schemaRebuildAt>10 then
        D.schemaRebuildAt=now; pcall(SCH.build,false); root=SCH.nodes and SCH.nodes.sectionRoot
    end
    if not root or not root.Parent then return nil,(SCH.slot and SCH.slot.status) or "PLAYER_DATA_NOT_FOUND" end
    local q=root:FindFirstChild("Quests"); local h=q and q:FindFirstChild("Holder")
    if not h then return nil,"QUEST_HOLDER_NOT_FOUND" end
    return h,nil
end
local function readQuests(now)
    local h,why=questHolder(now)
    if not h then return {},why end
    local out={}
    local list=h:GetChildren()
    table.sort(list,function(a,b) return a.Name<b.Name end)
    for i,q in ipairs(list) do
        if i>12 then break end
        local target,progress,required=nil,nil,nil
        local tasks=q:FindFirstChild("Tasks")
        if tasks then
            for _,t in ipairs(tasks:GetChildren()) do
                local code=val(t,"Code")
                if code~=nil and tostring(code)~="" then
                    target=trim(code)
                    local v=val(t,"Value"); local m=val(t,"Max")
                    progress=type(v)=="number" and v or nil; required=type(m)=="number" and m or nil
                    break
                end
            end
        end
        local qs=val(q,"QuestString")
        if not target then
            local text=trim(qs or q.Name)
            target=string.match(text,"[Dd]efeat%s+(.+)") or string.match(text,"[Ee]liminate%s+(.+)")
            target=target and trim(target) or nil
        end
        table.insert(out,{id=q:GetFullName(),name=q.Name,quest=trim(qs or q.Name),target=target,progress=progress,required=required})
    end
    return out,nil
end
D.readQuests=function() return readQuests(os.clock()) end

local function objectiveEnabled()
    local c=RAVYN.Config
    if not dc().FollowQuestData then return false end
    if c.Intelligence and c.Intelligence.AutoPlay then return true end
    return false
end
D.objectiveEnabled=objectiveEnabled
local function sourceOf(q)
    local CD=RAVYN.CrowDirect
    if CD and ((CD.lastQuestTarget and CD.lastQuestTarget==q.target) or (CD.pending and CD.pending.target==q.target)) then return "CROW" end
    local n=lower(q.name).." "..lower(q.quest)
    if string.find(n,"muzan",1,true) then return "MUZAN" end
    if string.find(n,"eliminate",1,true) then return "HUNT" end -- Boss Hunt claims create "Eliminate <boss>" (live traces #002/#004)
    return "QUEST"
end

-- ================= objective travel (single authority) =================
-- returns ok, code. Never teleports when the target is already engaged or streamed (targeting + ownership handle it).
function D.travelToObjective(name,source)
    name=trim(name); if name=="" then return false,"NO_TARGET" end
    local now=os.clock()
    local tr=D.travel[name] or {}; D.travel[name]=tr
    if tr.lastCall and now-tr.lastCall<.2 then return tr.ok,tr.code end
    tr.lastCall=now
    local function done(ok,code) tr.ok=ok; tr.code=code; return ok,code end
    local t=LiveAction.target
    if t and t.name==name then return done(true,"ENGAGED") end
    local LC=RAVYN.LootController
    if LC and LC.active then return done(true,"LOOT_FIRST") end
    -- external callers (Crow) only move the character for the objective DirectCore currently holds
    -- (a completed/turned-in quest target is never travelled to again)
    if source~="OBJECTIVE" and objectiveEnabled() then
        local ob=D.objective
        if not ob or ob.name~=name then return done(true,"NOT_CURRENT_OBJECTIVE") end
    end
    local e=D.findEntity(name)
    if e then tr.arrivedAt=nil; return done(true,"STREAMED") end
    if (tr.backoffUntil or 0)>now then return done(false,"LOCATION_BACKOFF") end
    local dest=nil
    local CD=RAVYN.CrowDirect
    if CD and CD.resolveCenter then local okC,p=pcall(CD.resolveCenter,name); if okC then dest=toV3(p) end end
    if not dest then
        local bm=RAVYN.BossMeta and RAVYN.BossMeta.byName and RAVYN.BossMeta.byName[name]
        dest=bm and toV3(bm.lastPos) or nil
    end
    if not dest then return done(false,"TARGET_LOCATION_UNKNOWN") end
    local root=liveRoot(); if not root then return done(false,"NO_ROOT") end
    local d=(root.Position-dest).Magnitude
    if d<=30 then
        tr.arrivedAt=tr.arrivedAt or now
        if now-tr.arrivedAt>(dc().ObjectiveStreamWait or 8) then
            tr.backoffUntil=now+(dc().ObjectiveTravelBackoff or 15); tr.arrivedAt=nil
            event(name.." not found at its last known spot · retrying later","warn")
            return done(false,"NOT_FOUND_AT_LAST_KNOWN_SPOT")
        end
        return done(true,"WAITING_FOR_STREAM")
    end
    tr.arrivedAt=nil
    if not requestTravel then return done(false,"TRAVEL_UNAVAILABLE") end
    local r=requestTravel(dest+Vector3.new(0,dc().ObjectiveArriveHeight or 6,0),"OBJECTIVE "..name,"obj:"..name,.8)
    return done(r~=nil and r.ok~=false,r and r.code or "TRAVEL_SENT")
end

-- ================= objective tick =================
local function objectiveTick(now)
    if not objectiveEnabled() then
        if D.objective then D.objective=nil; D.bump("objective") end
        D.state="OFF"; D.detail="Starts with Auto Play / START RAVYN"
        return
    end
    if now-D.lastQuestRead>=(dc().ObjectiveInterval or .5) then
        D.lastQuestRead=now
        local list,err=readQuests(now); D.quests=list; D.questError=err
    end
    local pick=nil
    for _,q in ipairs(D.quests) do
        local complete=q.progress~=nil and q.required~=nil and q.required>0 and q.progress>=q.required
        if q.target and q.target~="" and not complete then pick=q; break end
    end
    if not pick then
        if D.objective then event("Objective cleared · "..tostring(D.objective.name),"success"); D.objective=nil; D.bump("objective") end
        D.state=D.running() and "SEARCHING" or "READY"
        D.detail=D.questError and ("Quest data: "..tostring(D.questError)) or "No active quest objective"
        return
    end
    local ob=D.objective
    if not ob or ob.id~=pick.id or ob.name~=pick.target then
        D.bump("objective")
        ob={id=pick.id,name=pick.target,quest=pick.quest,questName=pick.name,source=sourceOf(pick),since=now}
        D.objective=ob
        event("Objective · "..ob.source.." · "..ob.name,"info")
    end
    ob.progress=pick.progress; ob.required=pick.required
    local e=D.findEntity(ob.name)
    ob.entity=e; ob.streamed=e~=nil
    if e then ob.parked=false; ob.lostSince=nil end
    if e then
        ob.boss=e.isBoss==true or e.classification=="BOSS"
        local okA,allowed,why=pcall(D.withExplicitRules,targetAllowed,e,ob.boss and "BOSS" or "MOB")
        ob.blocked=(okA and not allowed) and tostring(why) or nil
    else ob.blocked=nil end
    if not D.running() then D.state="READY"; D.detail=ob.name; return end
    if ob.blocked then D.state="UNAVAILABLE"; D.detail=ob.name.." · skipped by target rules ("..ob.blocked..")"; return end
    if not ob.streamed then
        local LC=RAVYN.LootController
        if LC and LC.active then D.state="LOOTING"; D.detail="Collecting loot before "..ob.name; return end
        local okT,code=D.travelToObjective(ob.name,ob.source)
        ob.travelCode=code
        local lost=code=="TARGET_LOCATION_UNKNOWN" or code=="LOCATION_BACKOFF" or code=="NOT_FOUND_AT_LAST_KNOWN_SPOT"
        if lost then
            -- an objective whose target cannot be located (e.g. a non-NPC task code) must not freeze all other work:
            -- after 20 s it is parked (still shown) and normal farming resumes until the target appears.
            ob.lostSince=ob.lostSince or now
            if not ob.parked and now-ob.lostSince>20 then ob.parked=true; event(ob.name.." not found in the world · continuing other work","warn") end
            D.state="SEARCHING"
        else ob.lostSince=nil; D.state="TRAVELING" end
        D.detail=ob.name.." · "..(ob.parked and "parked, target not in world" or string.lower(string.gsub(tostring(code),"_"," ")))
        return
    end
    D.state=D.activity(ob.name)
    D.detail=ob.name..(ob.progress and string.format(" · %d/%d",ob.progress,ob.required or 0) or "")
end

-- ================= target override (applied only for the duration of one automation tick) =================
function D.targetOverride()
    local ob=D.objective
    if ob and ob.streamed and ob.entity and not ob.blocked and objectiveEnabled() then
        return {name=ob.name,boss=ob.boss==true,source=ob.source,explicit=true}
    end
    local BC=RAVYN.BossController
    if BC and BC.choice and BC.applies and BC.applies() then return {name=BC.choice.name,boss=true,source="BOSS_FARM",explicit=BC.choice.selected==true} end
    return nil
end
local baseTick=RAVYN._tick
function RAVYN:_tick()
    local ov=nil
    local okO,res=pcall(D.targetOverride); if okO then ov=res end
    local saved=nil
    if ov then
        saved={mode=self.Config.AutoPlayV38.Mode,mob=self.Config.Farm.NormalMobs.TargetName,boss=self.Config.Farm.Boss.TargetName}
        if self.Config.Intelligence.AutoPlay then self.Config.AutoPlayV38.Mode=ov.boss and "Bosses" or "Mobs" end
        if ov.boss then self.Config.Farm.Boss.TargetName=ov.name else self.Config.Farm.NormalMobs.TargetName=ov.name end
    end
    D.appliedOverride=ov
    local ok,err
    if ov and ov.explicit then ok,err=pcall(D.withExplicitRules,baseTick,self) else ok,err=pcall(baseTick,self) end
    if saved then self.Config.AutoPlayV38.Mode=saved.mode; self.Config.Farm.NormalMobs.TargetName=saved.mob; self.Config.Farm.Boss.TargetName=saved.boss end
    -- target change token
    local tid=LiveAction.targetId
    if tid~=D.lastTargetId then D.lastTargetId=tid; D.bump("target") end
    if not ok then error(err) end
end

-- ================= lifecycle =================
D.token=(D.token or 0)+1
local token=D.token
task.spawn(function()
    while not RAVYN._destroyed and D.token==token do
        local ok,err=pcall(objectiveTick,os.clock())
        if not ok then D.detail="DIRECT_TICK_ERROR"; RAVYN.Logger:log("ERROR","DIRECT_TICK",{error=tostring(err)}) end
        task.wait(.25)
    end
end)
do
    local p=game:GetService("Players").LocalPlayer
    if p then table.insert(RAVYN._connections,p.CharacterAdded:Connect(function() D.bump("respawn"); D.travel={} end)) end
end
local baseStop=RAVYN.Stop
function RAVYN:Stop()
    D.bump("stop"); D.bump("objective"); D.objective=nil; D.travel={}; D.appliedOverride=nil
    D.state="OFF"; D.detail="Stopped"
    return baseStop(self)
end
local baseDestroy=RAVYN.Destroy
function RAVYN:Destroy()
    D.token=D.token+1; for k in pairs(D.gens) do D.gens[k]=D.gens[k]+1 end
    D.objective=nil; D.travel={}
    return baseDestroy(self)
end
-- Crow Hunts switch: the Direct Crow controller + the objective pipeline that fights the claimed target
function RAVYN:SetCrowHunts(v)
    if type(v)~="boolean" then return result(false,"INVALID_CONFIG") end
    local r=self:SetConfig("CrowDirect.Enabled",v); if not r.ok then return r end
    if v and not self.Config.Intelligence.AutoPlay then local r2=self:SetAutoPlay(true); if r2 and not r2.ok then return r2 end end
    if v and self.FSM.state=="STOPPED" then self:Start() end
    return result(true,v and "CROW_HUNTS_ON" or "CROW_HUNTS_OFF")
end
function RAVYN:GetObjectiveStatus()
    local ob=D.objective
    return result(true,"OBJECTIVE_STATUS",{state=D.state,detail=D.detail,name=ob and ob.name,source=ob and ob.source,progress=ob and ob.progress,
        required=ob and ob.required,streamed=ob and ob.streamed,quests=#D.quests,dataError=D.questError})
end
CTX["Direct11"]=D
RAVYN.Logger:log("INFO","DIRECT_CORE_V11_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("BossControllerV11.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Util=CTX["Util"]
local Config=CTX["Config"]
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local Brain=CTX["Brain"]
local liveRoot=CTX["liveRoot"]
local requestTravel=CTX["requestTravel384"]
local targetAllowed=CTX["targetAllowed"]
local D=CTX["Direct11"]
-- RAVYN DIRECT v1.1 · BossController
-- Chooses WHICH boss (single / multi-select / rotation / skip respawning) from the ActiveNpcs + BossInfo reads RAVYN
-- already uses. Movement stays with TravelController, combat with CombatMobility, loot with LootController.
local defaults={
    Enabled=false,
    Selected={},               -- boss names; empty = any eligible boss
    Rotation=true,             -- cycle the selection in order after each confirmed kill
    SkipRespawning=true,
    RespawnSkipSeconds=45,
    TravelToRemembered=true,   -- selected boss not streamed → teleport to its last observed position
    StreamWait=8,
    UnavailableBackoff=60,
    ReturnWindow=45,           -- only return after death if this boss was engaged within the window
}
Config.Default.BossFarm=Util.deepCopy(defaults)
RAVYN.Config.BossFarm=Util.deepMerge(defaults,RAVYN.Config.BossFarm or {})
local function bc() return RAVYN.Config.BossFarm end

local BC={state="OFF",detail="",choice=nil,list={},kills=0,killedAt={},unavailable={},lastKilled=nil,
    respawnGen=0,lastRespawn=nil,travel=nil,seenResolutions=0,roster={},rosterAt=-math.huge}
RAVYN.BossController=BC

local function now() return os.clock() end
local function explicit()
    local c=RAVYN.Config
    if bc().Enabled or (c.Farm and c.Farm.Boss and c.Farm.Boss.Enabled) then return true end
    local GO=RAVYN.GoState
    return GO~=nil and GO.active and not GO.paused and GO.goal=="BOSS_FARM"
end
function BC.applies()
    if explicit() then return true end
    local c=RAVYN.Config
    return c.Intelligence and c.Intelligence.AutoPlay and c.AutoPlayV38 and c.AutoPlayV38.Mode=="Smart" and c.AutoPlayV38.BossRotation==true or false
end
BC.explicit=explicit
local function selectedSet()
    local set={}; local n=0
    for _,name in ipairs(bc().Selected or {}) do if type(name)=="string" and name~="" then set[name]=true; n=n+1 end end
    return set,n
end
local function recentlyDown(name,t)
    local skip=bc().RespawnSkipSeconds or 45
    if (BC.killedAt[name] or -math.huge)>t-skip then return true end
    for _,m in pairs((Brain and Brain.bossMemory) or {}) do
        if m.name==name and m.lastDownAt and t-m.lastDownAt<skip and not m.alive then return true end
    end
    return false
end

-- ---------- roster (streamed + remembered + Boss Hunts content identities) ----------
local function refreshRoster(t)
    if t-BC.rosterAt<5 and next(BC.roster) then return end
    BC.rosterAt=t
    local r={}
    for name,m in pairs((RAVYN.BossMeta and RAVYN.BossMeta.byName) or {}) do r[name]={remembered=true,lastPos=m.lastPos,chest=m.chest,onlyAtNight=m.onlyAtNight} end
    local SCH=RAVYN.RuntimeSchema
    local ids=SCH and SCH.identities and SCH.identities.crowBossHuntNpcs or {}
    for _,name in ipairs(ids) do r[name]=r[name] or {content=true} end
    BC.roster=r
end

-- ---------- per-tick status list + choice ----------
local function statusFor(name,e,t,selected)
    local meta=(RAVYN.BossMeta and RAVYN.BossMeta.byName and RAVYN.BossMeta.byName[name]) or {}
    local st={name=name,chest=meta.chest,onlyAtNight=meta.onlyAtNight==true,lastPos=meta.lastPos}
    if e then
        st.id=e.id; st.distance=e.distance; st.health=e.health; st.maxHealth=e.maxHealth
        st.hpPct=(e.health and e.maxHealth and e.maxHealth>0) and math.clamp(e.health/e.maxHealth*100,0,100) or nil
        -- a boss you selected is explicit: only NeverAttack/civilian rules apply, not the automatic risk rating
        local okA,allowed,why
        if selected then okA,allowed,why=pcall(D.withExplicitRules,targetAllowed,e,"BOSS") else okA,allowed,why=pcall(targetAllowed,e,"BOSS") end
        if okA and not allowed then st.status="SKIPPED"; st.reason=tostring(why)
        else st.status="ALIVE" end
    elseif recentlyDown(name,t) and bc().SkipRespawning then st.status="RESPAWNING"
    elseif (BC.unavailable[name] or 0)>t then st.status="UNAVAILABLE"; st.reason="not found at last known spot"
    elseif st.lastPos then st.status="NOT_STREAMED"
    else st.status="UNKNOWN_LOCATION" end
    return st
end
local function tick()
    local t=now()
    refreshRoster(t)
    local s=RAVYN.Features and RAVYN.Features.snapshot or {}
    -- nearest alive streamed boss per name
    local streamed={}
    for _,e in ipairs(s.npcs or {}) do
        if (e.isBoss==true or e.classification=="BOSS") and e.alive~=false and (tonumber(e.health) or 0)>0 and e.position then
            local cur=streamed[e.name]
            if not cur or (e.distance or math.huge)<(cur.distance or math.huge) then streamed[e.name]=e end
        end
    end
    -- confirmed kills come from the TargetCombatSession death handoff (AutoPlay384)
    local AP=RAVYN.AutoPlay384; local Hh=AP and AP.handoff
    if Hh and (Hh.resolutions or 0)>BC.seenResolutions then
        BC.seenResolutions=Hh.resolutions or 0
        if Hh.lastBoss then
            BC.killedAt[Hh.lastBoss]=t; BC.lastKilled=Hh.lastBoss; BC.kills=BC.kills+1
            if BC.choice and BC.choice.name==Hh.lastBoss then BC.choice=nil; D.bump("boss") end
        end
    end
    -- status list (selection first, then everything else known)
    local set,nsel=selectedSet()
    local names={}; local seen={}
    for _,n in ipairs(bc().Selected or {}) do if not seen[n] then seen[n]=true; table.insert(names,n) end end
    local others={}
    for n in pairs(streamed) do if not seen[n] then seen[n]=true; table.insert(others,n) end end
    for n in pairs(BC.roster) do if not seen[n] then seen[n]=true; table.insert(others,n) end end
    table.sort(others)
    for _,n in ipairs(others) do table.insert(names,n) end
    local list={}
    for i,n in ipairs(names) do if i>40 then break end; local st=statusFor(n,streamed[n],t,set[n]==true); st.selected=set[n]==true; table.insert(list,st) end
    BC.list=list
    -- choice
    if not BC.applies() then BC.choice=nil; BC.travel=nil; BC.state="OFF"; BC.detail=""; return end
    local function usable(st) return st.status=="ALIVE" and (nsel==0 or st.selected) end
    local cur=BC.choice
    if cur then
        local st=nil; for _,x in ipairs(list) do if x.name==cur.name then st=x; break end end
        if not (st and usable(st)) then cur=nil end
    end
    if not cur then
        local pick=nil
        if nsel>0 and bc().Rotation then
            -- rotate: start after the last killed boss in selection order
            local sel=bc().Selected; local start=1
            for i,n in ipairs(sel) do if n==BC.lastKilled then start=i+1; break end end
            for k=0,#sel-1 do
                local n=sel[((start-1+k)%#sel)+1]
                for _,x in ipairs(list) do if x.name==n and usable(x) then pick=x; break end end
                if pick then break end
            end
        else
            local bd=math.huge
            for _,x in ipairs(list) do if usable(x) and (x.distance or math.huge)<bd then pick,bd=x,x.distance or math.huge end end
        end
        if pick then BC.choice={name=pick.name,id=pick.id,since=t,selected=pick.selected==true}; BC.travel=nil; D.bump("boss") end
        cur=BC.choice
    end
    if cur then
        BC.travel=nil
        local a=D.activity(cur.name)
        BC.state=a; BC.detail=cur.name
        return
    end
    -- nothing streamed: explicit boss farm may travel to a selected boss's last observed position
    -- (a quest objective or a loot session owns travel first: one movement authority at a time)
    local LCx=RAVYN.LootController
    local busy=(D.objective~=nil and D.objectiveEnabled()) or (LCx and LCx.active) or LiveAction.target~=nil
    if explicit() and bc().TravelToRemembered and nsel>0 and D.running() and not busy then
        local target=nil
        for _,x in ipairs(list) do if x.selected and x.status=="NOT_STREAMED" and x.lastPos then target=x; break end end
        if target then
            local dest=D.toV3(target.lastPos); local root=liveRoot()
            if dest and root then
                local tr=BC.travel
                if not tr or tr.name~=target.name then tr={name=target.name,since=t}; BC.travel=tr end
                local d=(root.Position-dest).Magnitude
                if d<=30 then
                    tr.arrivedAt=tr.arrivedAt or t
                    if t-tr.arrivedAt>(bc().StreamWait or 8) then
                        BC.unavailable[target.name]=t+(bc().UnavailableBackoff or 60); BC.travel=nil
                        D.event(target.name.." not found at last known spot · skipping for now","warn")
                    end
                    BC.state="SEARCHING"; BC.detail=target.name.." · waiting for it to appear"
                else
                    local h=(RAVYN.Config.CombatMobility and RAVYN.Config.CombatMobility.FlyHeight) or 6
                    if requestTravel then requestTravel(dest+Vector3.new(0,h,0),"BOSS "..target.name,"boss:"..target.name,.8) end
                    BC.state="TRAVELING"; BC.detail=target.name.." · last known position"
                end
                return
            end
        end
        local cool=false; for _,x in ipairs(list) do if x.selected and x.status=="RESPAWNING" then cool=true end end
        BC.state=cool and "COOLDOWN" or "SEARCHING"; BC.detail=cool and "Selected bosses are respawning" or "No selected boss available"
        return
    end
    BC.state=D.running() and "SEARCHING" or "READY"; BC.detail=nsel>0 and "Waiting for a selected boss" or "Waiting for any boss"
end

-- ---------- respawn return (called by TravelController on CharacterAdded) ----------
function BC.onRespawn(char,boss)
    BC.respawnGen=BC.respawnGen+1; local gen=BC.respawnGen
    local tcx=RAVYN.Config.TravelController or {}
    if not boss or not boss.at or os.clock()-boss.at>(bc().ReturnWindow or 45) then
        BC.lastRespawn={result="NO_RECENT_BOSS",at=os.clock()}; return
    end
    task.spawn(function()
        local root=char and char:WaitForChild("HumanoidRootPart",12)
        if not root or gen~=BC.respawnGen or RAVYN._destroyed then return end
        task.wait(tcx.RespawnReturnDelay or 1.25)
        if gen~=BC.respawnGen or RAVYN._destroyed or not D.running() then return end
        pcall(function() RAVYN:RefreshReadBindings() end)
        local e=nil
        for _,x in ipairs((RAVYN.Features.snapshot or {}).npcs or {}) do
            if x.id==boss.id and x.alive~=false and (tonumber(x.health) or 0)>0 and x.position then e=x; break end
        end
        if not e and boss.name then e=D.findEntity(boss.name) end
        if not e or not (e.isBoss==true or e.classification=="BOSS") then
            BC.lastRespawn={result="BOSS_GONE",boss=boss.name,at=os.clock()}
            D.event("Respawned · "..tostring(boss.name).." is gone, continuing","info"); return
        end
        local pos=D.toV3(e.position); if not pos then return end
        local h=(RAVYN.Config.CombatMobility and RAVYN.Config.CombatMobility.FlyHeight) or tcx.ArriveHeight or 5.5
        local MO=RAVYN.MoveOwner; if MO then MO.lastTeleportKey=nil; MO.lastTeleportDest=nil end
        local r=requestTravel and requestTravel(pos+Vector3.new(0,h,0),"RETURN TO BOSS · "..tostring(e.name),"respawn-boss:"..tostring(e.id),.8)
        LiveAction.targetId=e.id -- sticky: the same boss is re-acquired first
        BC.lastRespawn={result=r and r.code or "SENT",boss=e.name,at=os.clock()}
        if MO then MO.lastRespawnReturn={at=os.clock(),boss=e.name,code=r and r.code} end
        D.event("Respawned · returning to "..tostring(e.name),"success")
    end)
end

-- ---------- public API ----------
function RAVYN:SetBossFarm(v)
    if type(v)~="boolean" then return result(false,"INVALID_CONFIG") end
    local r=self:SetConfig("BossFarm.Enabled",v); if not r.ok then return r end
    if not self.Config.Intelligence.AutoPlay then
        local r2=self:SetFeature("BOSS",v); if not r2.ok then return r2 end
    elseif v and self.FSM.state=="STOPPED" then self:Start() end
    if not v then BC.choice=nil; BC.travel=nil end
    return result(true,v and "BOSS_FARM_ON" or "BOSS_FARM_OFF")
end
function RAVYN:ToggleBossSelected(name)
    if type(name)~="string" or name=="" then return result(false,"INVALID_NAME") end
    local list=Util.deepCopy(self.Config.BossFarm.Selected or {}); local found=nil
    for i,n in ipairs(list) do if n==name then found=i; break end end
    if found then table.remove(list,found) else table.insert(list,name) end
    local r=self:SetConfig("BossFarm.Selected",list)
    if r.ok then BC.choice=nil end
    return r.ok and result(true,found and "BOSS_UNSELECTED" or "BOSS_SELECTED",{name=name}) or r
end
function RAVYN:ClearBossSelection() BC.choice=nil; return self:SetConfig("BossFarm.Selected",{}) end
function RAVYN:GetBossFarmStatus()
    return result(true,"BOSS_FARM_STATUS",{state=BC.state,detail=BC.detail,choice=BC.choice and BC.choice.name,kills=BC.kills,list=BC.list,lastRespawn=BC.lastRespawn})
end

BC.token=(BC.token or 0)+1
local token=BC.token
task.spawn(function()
    while not RAVYN._destroyed and BC.token==token do
        local ok,err=pcall(tick)
        if not ok then BC.detail="BOSS_TICK_ERROR"; RAVYN.Logger:log("ERROR","BOSS_CONTROLLER_TICK",{error=tostring(err)}) end
        task.wait(.25)
    end
end)
local baseStop=RAVYN.Stop
function RAVYN:Stop()
    BC.respawnGen=BC.respawnGen+1; BC.choice=nil; BC.travel=nil; BC.state="OFF"
    return baseStop(self)
end
local baseDestroy=RAVYN.Destroy
function RAVYN:Destroy() BC.token=BC.token+1; BC.respawnGen=BC.respawnGen+1; BC.choice=nil; return baseDestroy(self) end
CTX["BossController11"]=BC
RAVYN.Logger:log("INFO","BOSS_CONTROLLER_V11_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("WorldSystemsV11.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Util=CTX["Util"]
local Config=CTX["Config"]
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local liveRoot=CTX["liveRoot"]
local requestTravel=CTX["requestTravel384"]
local D=CTX["Direct11"]
-- RAVYN DIRECT v1.1 · Muzan + Training controllers.
-- Evidence available today: world "Muzan" instance with a ProximityPrompt (FeatureRegistry candidate), QuestStates
-- "Muzan Quest", Ouwland.Content trainer identities, Workspace.Training stations with ProximityPrompts, the
-- ComponentsHolder.DialogueFrame.NpcName dialogue path (Crow evidence) and local quest data.
-- Sub-actions without evidence (Muzan task selection, training minigames) are reported UNAVAILABLE, never invented.
local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local function exec(name) local f=(getgenv and getgenv()[name]) or G[name]; return type(f)=="function" and f or nil end
local function lower(v) return string.lower(tostring(v or "")) end
local function posOf(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Model") then local ok,cf=pcall(function() return inst:GetPivot() end); if ok then return cf.Position end end
    local bp=inst:FindFirstAncestorWhichIsA("BasePart") or inst:FindFirstChildWhichIsA("BasePart",true)
    return bp and bp.Position or nil
end
local function firstPrompt(inst)
    if not inst then return nil end
    local ok,p=pcall(function() return inst:FindFirstChildWhichIsA("ProximityPrompt",true) end)
    return ok and p or nil
end
-- dialogue GUI (same verified path the Crow controller uses)
local function dialogue()
    local pg=LP and LP:FindFirstChildOfClass("PlayerGui"); local c=pg and pg:FindFirstChild("ComponentsHolder")
    local frame=c and c:FindFirstChild("DialogueFrame")
    local npc=frame and frame:FindFirstChild("NpcName",true)
    local visible=frame and frame:IsA("GuiObject") and frame.Visible
    return npc and npc.Text or nil,visible,c and c:FindFirstChild("DialogueContent")
end
local function dialogueLines(content,limit)
    local out={}
    if not content then return out end
    local ok,desc=pcall(function() return content:GetDescendants() end)
    if not ok then return out end
    for i,d in ipairs(desc) do
        if i>200 or #out>=(limit or 6) then break end
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible and d.Text~="" then table.insert(out,D.trim(d.Text)) end
    end
    return out
end
local function firePrompt(pr)
    local f=exec("fireproximityprompt"); if not f then return false,"FIREPROXIMITYPROMPT_UNAVAILABLE" end
    local ok=pcall(function() f(pr,math.max(pr.HoldDuration or 0,0)) end)
    return ok,ok and "PROMPT_SENT" or "PROMPT_ERROR"
end

-- ================= MUZAN =================
Config.Default.MuzanDirect={Enabled=false,AutoInteract=false,ScanInterval=10,InteractCooldown=8,VerifyWindow=2.5}
RAVYN.Config.MuzanDirect=Util.deepMerge(Config.Default.MuzanDirect,RAVYN.Config.MuzanDirect or {})
local function mc() return RAVYN.Config.MuzanDirect end
local MZ={state="OFF",detail="",found=nil,lastScan=-math.huge,pending=nil,lastInteract=-math.huge,dialogue={},claimUntil=0,restUntil=0,visitAt=nil,
    sub={find="READY",teleport="READY",interact="PARTIAL",accept="UNAVAILABLE",objective="PARTIAL",repeatTask="UNAVAILABLE"}}
RAVYN.MuzanController=MZ
local function findMuzan(t,force)
    -- 1) streamed NPC enumeration (ActiveNpcs)
    for _,name in ipairs({"Muzan","Roaming Muzan"}) do
        local e=D.findEntity(name)
        if e then
            local raw=RAVYN.ReadAdapter and RAVYN.ReadAdapter.lastEntities and RAVYN.ReadAdapter.lastEntities[e.id]
            return {name=name,pos=D.toV3(e.position),inst=raw,prompt=firstPrompt(raw),via="ActiveNpcs"}
        end
    end
    -- 2) bounded identity lookup (C-side recursive FindFirstChild), at most every ScanInterval seconds
    if not force and t-MZ.lastScan<(mc().ScanInterval or 10) then return MZ.found end
    MZ.lastScan=t
    local ok,inst=pcall(function() return workspace:FindFirstChild("Muzan",true) end)
    if ok and inst then return {name="Muzan",pos=posOf(inst),inst=inst,prompt=firstPrompt(inst),via="world identity"} end
    return nil
end
local function muzanTick(t)
    if not mc().Enabled then MZ.state="OFF"; MZ.detail=""; MZ.pending=nil; return end
    local ob=D.objective
    if ob and ob.source=="MUZAN" then MZ.state=D.state; MZ.detail="Task · "..tostring(ob.name); MZ.visitAt=nil; return end
    if ob and D.objectiveEnabled() then MZ.state="READY"; MZ.detail="Current objective first ("..tostring(ob.name)..")"; MZ.visitAt=nil; return end
    if t<MZ.restUntil then MZ.state="COOLDOWN"; MZ.detail=string.format("Next Muzan visit in %.0fs",MZ.restUntil-t); return end
    local f=findMuzan(t,false); MZ.found=f
    if not f or not f.pos then MZ.state="SEARCHING"; MZ.detail="Muzan is not streamed right now"; MZ.sub.find="SEARCHING"; return end
    MZ.sub.find="READY"
    local root=liveRoot(); if not root then return end
    local d=(root.Position-f.pos).Magnitude
    local reach=(f.prompt and math.max(4,(f.prompt.MaxActivationDistance or 10)-2)) or 8
    if d>reach then
        if not D.running() then MZ.state="READY"; MZ.detail=string.format("Muzan found · %.0f studs",d); return end
        -- one movement authority: never pull the character away from a fight or a loot session
        local LA=CTX["LiveAction"]; local LC=RAVYN.LootController
        if (LA and LA.target) or (LC and LC.active) then MZ.state="READY"; MZ.detail="Muzan found · waiting for the current fight/loot"; return end
        local away=(root.Position-f.pos); away=Vector3.new(away.X,0,away.Z); away=away.Magnitude>1 and away.Unit or Vector3.new(1,0,0)
        if requestTravel then requestTravel(f.pos+away*math.min(4,reach-1)+Vector3.new(0,2,0),"MUZAN","muzan",.8) end
        MZ.claimUntil=t+1.2 -- the scheduler holds new target acquisition while Muzan owns travel
        MZ.state="TRAVELING"; MZ.detail="Going to Muzan"; return
    end
    -- a visit is bounded: without progress for 20 s RAVYN resumes other work and comes back later
    MZ.visitAt=MZ.visitAt or t
    if t-MZ.visitAt>20 and not MZ.pending then MZ.visitAt=nil; MZ.restUntil=t+90; MZ.state="COOLDOWN"; MZ.detail="No task picked · back in 90 s"; return end
    MZ.claimUntil=t+1.2
    local npcText,vis,content=dialogue()
    if npcText and string.find(lower(npcText),"muzan",1,true) and vis~=false then
        MZ.dialogue=dialogueLines(content,6); MZ.pending=nil
        MZ.state="READY"; MZ.detail="Dialogue open · choose the task yourself (selection not mapped)"; return
    end
    if MZ.pending then
        if t-MZ.pending.at>(mc().VerifyWindow or 2.5) then
            MZ.pending=nil; MZ.lastInteract=t+10; MZ.sub.interact="UNVERIFIED"
            MZ.state="COOLDOWN"; MZ.detail="Prompt fired but no Muzan dialogue appeared · backing off"
        end
        return
    end
    if not mc().AutoInteract or not D.running() then MZ.state="READY"; MZ.detail="At Muzan · press the prompt yourself or enable auto interact"; return end
    if not f.prompt then MZ.state="UNAVAILABLE"; MZ.detail="No interaction prompt on Muzan"; MZ.sub.interact="UNAVAILABLE"; return end
    if t-MZ.lastInteract<(mc().InteractCooldown or 8) then MZ.state="COOLDOWN"; MZ.detail="Interaction cooldown"; return end
    MZ.lastInteract=t
    local ok,code=firePrompt(f.prompt)
    if ok then MZ.pending={at=t}; MZ.state="READY"; MZ.detail="Opening Muzan dialogue…" else MZ.state="UNAVAILABLE"; MZ.detail=code end
end
-- scheduler hold: while Muzan owns travel/visit, no new farm target is acquired (a running fight is never interrupted)
local Hooks=CTX.Hooks
local baseChoose=Hooks.chooseMode
Hooks.chooseMode=function()
    local LA=CTX["LiveAction"]
    if mc().Enabled and os.clock()<(MZ.claimUntil or 0) and not (LA and LA.target) then
        local JS=RAVYN.JobScheduler
        if JS then JS.job="MUZAN"; JS.label="MUZAN · "..tostring(MZ.detail); JS.allowMovement=false; JS.mode=nil end
        return nil,false,"MUZAN"
    end
    return baseChoose()
end
function RAVYN:SetMuzan(key,v)
    local allowed={Enabled=true,AutoInteract=true}
    if not allowed[key] or type(v)~="boolean" then return result(false,"INVALID_MUZAN_OPTION") end
    local r=self:SetConfig("MuzanDirect."..key,v)
    if r.ok and key=="Enabled" and v and self.FSM.state=="STOPPED" then self:Start() end
    return r
end
function RAVYN:TeleportToMuzan()
    local f=findMuzan(os.clock(),true); MZ.found=f
    if not f or not f.pos then return result(false,"MUZAN_NOT_STREAMED") end
    if not requestTravel then return result(false,"TRAVEL_UNAVAILABLE") end
    return requestTravel(f.pos+Vector3.new(3,2,0),"MUZAN","muzan-manual",.8)
end

-- ================= TRAINING =================
Config.Default.TrainingDirect={SelectedStyle=""}
RAVYN.Config.TrainingDirect=Util.deepMerge(Config.Default.TrainingDirect,RAVYN.Config.TrainingDirect or {})
local STYLES={"Flame","Thunder","Water","Wind","Stone","Serpent","Insect","Sound","Moon","Mist","Love","Beast","Sun"}
local TRAINERS={"Flame","Thunder","Water","Wind","Stone","Serpent","Insect","Sound"}
local TC={state="READY",detail="",detected=nil,detectedFrom=nil,trainers={},stations={},scannedAt=nil,mastery=nil,masteryAt=-math.huge,pending=nil,
    sub={select="READY",teleport="READY",interact="PARTIAL",minigame="UNAVAILABLE",progress="PARTIAL"}}
RAVYN.TrainingController=TC
TC.TRAINERS=TRAINERS
local function styleIn(text)
    local l=lower(text)
    for _,s in ipairs(STYLES) do
        local ls=lower(s)
        if string.find(l,ls.." breath",1,true) or string.find(l,ls.."breath",1,true) then return s end
    end
    return nil
end
-- equipped style: hotbar skill names first, then local Powers data names (both local-player reads)
function TC.detect()
    local A=RAVYN.AdaptiveIntel
    for _,sk in ipairs((A and A.activeProfile and A.activeProfile.skills) or {}) do
        local s=styleIn(sk.name); if s then TC.detected=s; TC.detectedFrom="hotbar skill · "..tostring(sk.name); return s end
    end
    local DA=RAVYN.DataAdapters
    if DA and DA.Powers then
        local ok,tree=pcall(DA.Powers)
        if ok and type(tree)=="table" then
            local n=0
            local function walk(node)
                n=n+1; if n>300 or TC.detected then return end
                local s=styleIn(node.name) or (type(node.value)=="string" and styleIn(node.value))
                if s then TC.detected=s; TC.detectedFrom="player data · Powers"; return end
                for _,c in pairs(node.children or {}) do walk(c) end
            end
            TC.detected=nil; walk(tree)
            if TC.detected then return TC.detected end
        end
    end
    TC.detected=nil; TC.detectedFrom="not visible (no breathing skill on the hotbar or in Powers)"
    return nil
end
-- on demand only (Training page / buttons): trainer + station lookups are one-shot, never a loop
function TC.scan()
    local SCH=RAVYN.RuntimeSchema
    local content={}
    if SCH and SCH.get then local s=SCH.get(); content=(s.identities and s.identities.contentIdentity) or {} end
    for _,t in ipairs(TRAINERS) do
        local name=t.." Trainer"
        local ok,inst=pcall(function() return workspace:FindFirstChild(name,true) end)
        TC.trainers[t]={name=name,identity=content[name]~=nil,inst=ok and inst or nil,pos=(ok and inst) and posOf(inst) or nil,prompt=(ok and inst) and firstPrompt(inst) or nil}
    end
    TC.stations={}
    local tr=workspace:FindFirstChild("Training")
    if tr then
        for i,st in ipairs(tr:GetChildren()) do
            if i>40 then break end
            local pr=firstPrompt(st)
            table.insert(TC.stations,{name=st.Name,inst=st,pos=posOf(st),prompt=pr,action=pr and (pr.ActionText~="" and pr.ActionText or pr.ObjectText) or nil})
        end
    end
    TC.scannedAt=os.clock()
    return TC
end
function TC.readMastery()
    local t=os.clock(); if t-TC.masteryAt<10 then return TC.mastery end
    TC.masteryAt=t
    local DA=RAVYN.DataAdapters; if not (DA and DA.Mastery) then TC.mastery=nil; return nil end
    local ok,tree,err=pcall(DA.Mastery)
    if not ok or type(tree)~="table" then TC.mastery={error=tostring(err or tree)}; return TC.mastery end
    local rows={}
    for name,node in pairs(tree.children or {}) do
        local v=node.value
        if v==nil and node.children then local nkids=0; for _ in pairs(node.children) do nkids=nkids+1 end; v=nkids.." entries" end
        table.insert(rows,{name=name,value=tostring(v)})
    end
    table.sort(rows,function(a,b) return a.name<b.name end)
    TC.mastery={rows=rows}
    return TC.mastery
end
function RAVYN:SetTrainingStyle(style)
    if type(style)~="string" then return result(false,"INVALID_STYLE") end
    return self:SetConfig("TrainingDirect.SelectedStyle",style)
end
function RAVYN:TeleportToTrainer(style)
    style=style or self.Config.TrainingDirect.SelectedStyle
    if not style or style=="" then return result(false,"SELECT_A_STYLE") end
    local rec=TC.trainers[style]
    if not rec or not rec.inst or not rec.inst.Parent then TC.scan(); rec=TC.trainers[style] end
    if not rec or not rec.pos then TC.state="SEARCHING"; TC.detail=style.." Trainer is not streamed"; return result(false,"TRAINER_NOT_STREAMED") end
    if not requestTravel then return result(false,"TRAVEL_UNAVAILABLE") end
    TC.state="TRAVELING"; TC.detail="Going to "..style.." Trainer"
    return requestTravel(rec.pos+Vector3.new(3,2,0),"TRAINER "..style,"trainer:"..style,.8)
end
function RAVYN:TeleportToStation(index)
    local st=TC.stations[index]; if not st or not st.pos then return result(false,"STATION_NOT_FOUND") end
    if not requestTravel then return result(false,"TRAVEL_UNAVAILABLE") end
    TC.state="TRAVELING"; TC.detail="Going to station "..st.name
    return requestTravel(st.pos+Vector3.new(3,2,0),"STATION "..st.name,"station:"..st.name,.8)
end
-- fires the station's own ProximityPrompt once (what pressing its key does) and verifies a visible change.
-- The minigame itself is NOT automated: its input logic has no verified evidence.
function RAVYN:InteractTrainingStation(index)
    local st=TC.stations[index]; if not st or not st.prompt or not st.prompt.Parent then return result(false,"STATION_PROMPT_NOT_FOUND") end
    local root=liveRoot(); if not root or not st.pos then return result(false,"NO_ROOT") end
    local reach=math.max(4,(st.prompt.MaxActivationDistance or 10)-1.5)
    if (root.Position-st.pos).Magnitude>reach+4 then return result(false,"MOVE_CLOSER_FIRST") end
    local before=st.prompt.Enabled
    local ok,code=firePrompt(st.prompt)
    if not ok then return result(false,code) end
    TC.pending={at=os.clock(),index=index,before=before}
    TC.state="READY"; TC.detail="Station started · complete the minigame yourself"
    return result(true,"STATION_PROMPT_SENT")
end

-- ================= loop (only does work while its feature is enabled) =================
local token=(MZ.token or 0)+1; MZ.token=token
task.spawn(function()
    while not RAVYN._destroyed and MZ.token==token do
        local t=os.clock()
        local ok,err=pcall(muzanTick,t)
        if not ok then MZ.detail="MUZAN_TICK_ERROR"; RAVYN.Logger:log("ERROR","MUZAN_TICK",{error=tostring(err)}) end
        if TC.pending and t-TC.pending.at>2.5 then TC.pending=nil end
        if TC.state=="TRAVELING" then local MO=RAVYN.MoveOwner; if not (MO and MO.current=="TRAVEL") then TC.state="READY"; TC.detail="Arrived" end end
        task.wait(mc().Enabled and .5 or 1.5)
    end
end)
local baseStop=RAVYN.Stop
function RAVYN:Stop() MZ.pending=nil; TC.pending=nil; MZ.claimUntil=0; MZ.visitAt=nil; if MZ.state~="OFF" then MZ.state="READY" end; return baseStop(self) end
local baseDestroy=RAVYN.Destroy
function RAVYN:Destroy() MZ.token=MZ.token+1; MZ.found=nil; TC.trainers={}; TC.stations={}; return baseDestroy(self) end
CTX["Muzan11"]=MZ; CTX["Training11"]=TC
RAVYN.Logger:log("INFO","WORLD_SYSTEMS_V11_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("DungeonV11.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Util=CTX["Util"]
local Config=CTX["Config"]
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local CardScorer=CTX["CardScorer"]
-- RAVYN DIRECT v1.1 · Ouwigahara runtime controller structure.
-- There is NO live evidence yet for the queue, ready, card, vote-skip or leave GUI/actions (GameKnowledge:
-- OUWIGAHARA = RESEARCH_REQUIRED). Every such sub-action is exposed as UNAVAILABLE and refuses to run.
-- What IS live: the card ranking engine (your preferences), and floor combat through the normal combat pipeline
-- whenever dungeon enemies appear in the ActiveNpcs enumeration.
Config.Default.Ouwi11={AutoQueue=false,AutoReady=false,AutoFarmFloors=false,AutoSelectCards=false,AutoVoteSkip=false,AutoLeave=false}
RAVYN.Config.Ouwi11=Util.deepMerge(Config.Default.Ouwi11,RAVYN.Config.Ouwi11 or {})
-- card preferences (user-provided): blacklist · priority · low priority
Config.Default.Dungeon.LowPriority={"Attack Speed","Movement Speed"}
Config.Default.Dungeon.LowPriorityPenalty=14
if type(RAVYN.Config.Dungeon.LowPriority)~="table" then RAVYN.Config.Dungeon.LowPriority=Util.deepCopy(Config.Default.Dungeon.LowPriority) end
if type(RAVYN.Config.Dungeon.LowPriorityPenalty)~="number" then RAVYN.Config.Dungeon.LowPriorityPenalty=14 end
do -- make sure the documented priorities/blacklist are present even in older saved settings
    local d=RAVYN.Config.Dungeon
    for _,n in ipairs({"Iron Discipline","Grounded","Bare Hands"}) do if not Util.contains(d.Blacklist,n) then table.insert(d.Blacklist,n) end end
    local w={["Shared Points"]=35,["Lucky Draw"]=30,["Vampiric"]=26,["Streak"]=22,["Fortune"]=18}
    for k,v in pairs(w) do if type(d.Weights[k])~="number" then d.Weights[k]=v end end
end

local DG={state="UNAVAILABLE",detail="Ouwigahara GUI/actions are not mapped yet",runState="UNKNOWN",floor=nil,points=nil,
    sub={
        {key="AutoQueue",label="Auto queue",status="UNAVAILABLE",why="Queue menu action not observed"},
        {key="AutoReady",label="Auto ready",status="UNAVAILABLE",why="Ready button not observed"},
        {key="AutoFarmFloors",label="Auto farm floors",status="PARTIAL",why="Uses normal combat when dungeon enemies are in ActiveNpcs"},
        {key="AutoSelectCards",label="Auto select cards",status="UNAVAILABLE",why="Card GUI not observed · ranking engine ready"},
        {key="AutoVoteSkip",label="Auto vote skip",status="UNAVAILABLE",why="Vote GUI not observed"},
        {key="AutoLeave",label="Auto leave",status="UNAVAILABLE",why="Leave action not observed"},
    }}
RAVYN.DungeonController=DG

-- score one card name with the user's preferences; returns score, reason
function DG.scoreCard(name)
    local d=RAVYN.Config.Dungeon
    if Util.contains(d.Blacklist,name) then return -math.huge,"BLACKLISTED" end
    local s,why=CardScorer.score({name=name},d,{})
    if Util.contains(d.LowPriority or {},name) then s=s-(d.LowPriorityPenalty or 14); why="LOW PRIORITY" end
    if (d.Weights or {})[name] then why="PRIORITY" end
    return s,why
end
-- rank a list of card names (used by the card step once the card GUI is mapped; previewable now)
function DG.rank(names)
    local out={}
    for _,n in ipairs(names or {}) do local s,why=DG.scoreCard(n); table.insert(out,{name=n,score=s,reason=why}) end
    table.sort(out,function(a,b) return a.score>b.score end)
    return out
end
function RAVYN:RankDungeonCards(names) return result(true,"CARD_RANKING",DG.rank(names)) end
-- toggles: only sub-actions with a live path can be enabled
function RAVYN:SetDungeonOption(key,v)
    if type(v)~="boolean" then return result(false,"INVALID_CONFIG") end
    for _,s in ipairs(DG.sub) do
        if s.key==key then
            if v and s.status=="UNAVAILABLE" then return result(false,"ACTION_NOT_MAPPED",{feature=s.label}) end
            return self:SetConfig("Ouwi11."..key,v)
        end
    end
    return result(false,"UNKNOWN_DUNGEON_OPTION")
end
-- a saved ON for an unmapped action must never look live
function DG.enforce() for _,s in ipairs(DG.sub) do if s.status=="UNAVAILABLE" then RAVYN.Config.Ouwi11[s.key]=false end end end
DG.enforce()
function DG.status(key)
    for _,s in ipairs(DG.sub) do if s.key==key then
        if s.status=="UNAVAILABLE" then return "UNAVAILABLE",s.why end
        if not RAVYN.Config.Ouwi11[key] then return "OFF",s.why end
        local D=RAVYN.Direct
        return (D and D.activity and D.activity(nil)) or "READY",s.why
    end end
    return "UNAVAILABLE","unknown"
end
CTX["Dungeon11"]=DG
RAVYN.Logger:log("INFO","DUNGEON_V11_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("VisualsV11.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Util=CTX["Util"]
local Config=CTX["Config"]
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local liveRoot=CTX["liveRoot"]
local D=CTX["Direct11"]
-- RAVYN DIRECT v1.1 · Visuals (ESP)
-- Pooled BillboardGuis (+ a few Highlights for bosses / the quest target). Objects are created once per entity and
-- only their text/colour is updated; nothing is rebuilt per frame. NPCs come from the cached ActiveNpcs snapshot;
-- chests/drops come from a bounded sphere query (≤ 700 parts, every 1.5 s) only while those layers are on.
-- Other players are intentionally not tracked.
Config.Default.Visuals={Mobs=false,Bosses=false,QuestTarget=false,Chests=false,Drops=false,ShowName=true,ShowDistance=true,ShowHealth=true,MaxDistance=1500,WorldRadius=180}
RAVYN.Config.Visuals=Util.deepMerge(Config.Default.Visuals,RAVYN.Config.Visuals or {})
local function vc() return RAVYN.Config.Visuals end
-- migrate v3.7 NPC/Boss ESP flags into this layer (the old per-tick updater then stays idle).
-- Runs now and again after saved settings load at boot.
local function migrate()
    local e=RAVYN.Config.Intelligence and RAVYN.Config.Intelligence.ESP
    if e then
        if e.NPC then RAVYN.Config.Visuals.Mobs=true; e.NPC=false end
        if e.Boss then RAVYN.Config.Visuals.Bosses=true; e.Boss=false end
    end
end
migrate()
local baseLoad=RAVYN.LoadSettings
function RAVYN:LoadSettings(...)
    local r=baseLoad(self,...)
    pcall(migrate)
    local DG=RAVYN.DungeonController
    if DG and DG.enforce then pcall(DG.enforce) end
    return r
end

local Players=game:GetService("Players"); local LP=Players.LocalPlayer
local V={items={},count=0,folder=nil,hlFolder=nil,lastNpc=0,lastWorld=0,worldHits={},state="OFF",token=0,highlights=0}
RAVYN.Visuals=V
local MAX_ITEMS,MAX_HIGHLIGHTS=60,24
local COL={mob=Color3.fromRGB(240,240,245),boss=Color3.fromRGB(228,188,76),quest=Color3.fromRGB(162,128,250),chest=Color3.fromRGB(86,196,236),drop=Color3.fromRGB(74,206,132),target=Color3.fromRGB(92,151,255)}
local CHEST_WORDS={"chest","sealed","coffer","treasure"}
local DROP_WORDS={"pick","collect","loot","take","grab","claim","drop","soul","item","reward","orb","material"}
local QUEST_WORDS={"crow","muzan","quest","mission","talk","speak","train"}
local function hasAny(s,w) for _,x in ipairs(w) do if string.find(s,x,1,true) then return true end end; return false end
local function anyOn() local c=vc(); return c.Mobs or c.Bosses or c.QuestTarget or c.Chests or c.Drops end

local function ensureFolders()
    if not (V.folder and V.folder.Parent) then
        local pg=LP and LP:FindFirstChildOfClass("PlayerGui"); if not pg then return false end
        local old=pg:FindFirstChild("RAVYN_ESP_V11"); if old then old:Destroy() end
        local f=Instance.new("Folder"); f.Name="RAVYN_ESP_V11"; f.Parent=pg; V.folder=f
    end
    if not (V.hlFolder and V.hlFolder.Parent) then
        local old=workspace:FindFirstChild("RAVYN_ESP_HL"); if old then old:Destroy() end
        local f=Instance.new("Folder"); f.Name="RAVYN_ESP_HL"; f.Parent=workspace; V.hlFolder=f
    end
    return true
end
local function drop(key)
    local it=V.items[key]; if not it then return end
    for _,x in ipairs({it.gui,it.hl}) do if x then pcall(function() x:Destroy() end) end end
    if it.hl then V.highlights=V.highlights-1 end
    V.items[key]=nil; V.count=V.count-1
end
local function clearAll() for k in pairs(V.items) do drop(k) end; V.count=0; V.highlights=0 end
local function upsert(key,adornee,model,text,color,wantHl)
    local it=V.items[key]
    if not it then
        if V.count>=MAX_ITEMS then return end
        local gui=Instance.new("BillboardGui"); gui.Name="RAVYN_ESP"; gui.Size=UDim2.fromOffset(200,44); gui.StudsOffset=Vector3.new(0,3.6,0)
        gui.AlwaysOnTop=true; gui.LightInfluence=0; gui.MaxDistance=vc().MaxDistance or 1500; gui.Adornee=adornee; gui.Parent=V.folder
        local l=Instance.new("TextLabel"); l.Size=UDim2.fromScale(1,1); l.BackgroundTransparency=1; l.TextStrokeTransparency=.35
        l.TextSize=13; l.Font=Enum.Font.GothamSemibold; l.TextWrapped=true; l.Parent=gui
        it={gui=gui,label=l,adornee=adornee}; V.items[key]=it; V.count=V.count+1
    elseif it.adornee~=adornee then it.gui.Adornee=adornee; it.adornee=adornee end
    if it.label.Text~=text then it.label.Text=text end
    if it.color~=color then it.color=color; it.label.TextColor3=color end
    if wantHl and model and not it.hl and V.highlights<MAX_HIGHLIGHTS then
        local h=Instance.new("Highlight"); h.Adornee=model; h.FillTransparency=.78; h.OutlineTransparency=.1; h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        h.FillColor=color; h.OutlineColor=color; h.Parent=V.hlFolder; it.hl=h; V.highlights=V.highlights+1
    elseif it.hl and not wantHl then pcall(function() it.hl:Destroy() end); it.hl=nil; V.highlights=V.highlights-1
    elseif it.hl and it.hl.FillColor~=color then it.hl.FillColor=color; it.hl.OutlineColor=color end
end
local function label(name,dist,pct,tag)
    local c=vc(); local parts={}
    if c.ShowName then table.insert(parts,(tag and (tag.."  ") or "")..tostring(name)) end
    local sub={}
    if c.ShowHealth and pct then table.insert(sub,string.format("%d%%",math.floor(pct+.5))) end
    if c.ShowDistance and dist then table.insert(sub,string.format("%.0f studs",dist)) end
    if #sub>0 then table.insert(parts,table.concat(sub,"  ·  ")) end
    return table.concat(parts,"\n")
end
local function questName()
    local ob=D.objective; if ob and ob.name then return ob.name end
    local QB=RAVYN.QuestBrain; return QB and QB.targetName or nil
end

local function npcPass(seen)
    local c=vc(); local RA=RAVYN.ReadAdapter
    local qn=c.QuestTarget and questName() or nil
    local maxD=c.MaxDistance or 1500
    for _,e in ipairs((RAVYN.Features.snapshot or {}).npcs or {}) do
        local isBoss=e.isBoss==true or e.classification=="BOSS"
        local isQuest=qn~=nil and e.name==qn
        if e.alive~=false and (e.distance or 0)<=maxD and ((isQuest) or (isBoss and c.Bosses) or ((not isBoss) and c.Mobs)) then
            local raw=RA and RA.lastEntities and RA.lastEntities[e.id]
            local root=raw and RA:_entityRoot(raw)
            if root then
                local key="npc:"..e.id; seen[key]=true
                local pct=(e.health and e.maxHealth and e.maxHealth>0) and e.health/e.maxHealth*100 or nil
                local selected=LiveAction.targetId==e.id
                local color=(isQuest and COL.quest) or (selected and COL.target) or (isBoss and COL.boss) or COL.mob
                local tag=(isQuest and "◇ QUEST") or (isBoss and "◆ BOSS") or nil
                upsert(key,root,raw,label(e.name,e.distance,pct,tag),color,isBoss or isQuest)
            end
        end
    end
end
local function worldPass(seen,t)
    local c=vc()
    if not (c.Chests or c.Drops) then V.worldHits={}; return end
    local root=liveRoot(); if not root then return end
    if t-V.lastWorld>=1.5 then
        V.lastWorld=t; V.worldHits={}
        local params=OverlapParams.new(); if root.Parent then params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={root.Parent} end
        local ok,parts=pcall(function() return workspace:GetPartBoundsInRadius(root.Position,math.min(c.WorldRadius or 180,250),params) end)
        if ok then
            local done={}
            for i,p in ipairs(parts) do
                if i>700 then break end
                local m=p:FindFirstAncestorWhichIsA("Model"); local holder=(m and m~=workspace) and m or p
                if not done[holder] then
                    done[holder]=true
                    if not (holder:IsA("Model") and holder:FindFirstChildOfClass("Humanoid")) then
                        local okP,pr=pcall(function() return holder:FindFirstChildWhichIsA("ProximityPrompt",true) end)
                        if okP and pr and pr.Enabled then
                            local s=string.lower(pr.ActionText.." "..pr.ObjectText.." "..holder.Name)
                            if not hasAny(s,QUEST_WORDS) then
                                local kind=(hasAny(s,CHEST_WORDS) and "chest") or (hasAny(s,DROP_WORDS) and "drop") or nil
                                if kind then table.insert(V.worldHits,{holder=holder,part=p,kind=kind,name=(pr.ObjectText~="" and pr.ObjectText) or holder.Name}) end
                            end
                        end
                    end
                end
                if #V.worldHits>=30 then break end
            end
        end
    end
    for _,h in ipairs(V.worldHits) do
        if h.holder.Parent and ((h.kind=="chest" and c.Chests) or (h.kind=="drop" and c.Drops)) then
            local key=h.holder; seen[key]=true
            local d=h.part.Parent and (root.Position-h.part.Position).Magnitude or nil
            upsert(key,h.part,nil,label(h.name,d,nil,h.kind=="chest" and "▣ CHEST" or "• DROP"),h.kind=="chest" and COL.chest or COL.drop,false)
        end
    end
end
local function step(t)
    if not anyOn() then if V.count>0 then clearAll() end; V.state="OFF"; return end
    if not ensureFolders() then return end
    -- the automation loop refreshes the snapshot while running; when stopped, refresh it lightly for ESP
    if not D.running() and t-(D.snapshotAt or -math.huge)>.6 then pcall(function() RAVYN:RefreshReadBindings() end) end
    local seen={}
    npcPass(seen); worldPass(seen,t)
    for k in pairs(V.items) do if not seen[k] then drop(k) end end
    V.state="READY"
end
function RAVYN:SetVisual(key,v)
    if type(v)~="boolean" or vc()[key]==nil then return result(false,"INVALID_VISUAL_OPTION") end
    local r=self:SetConfig("Visuals."..key,v)
    if r.ok and not anyOn() then clearAll() end
    return r
end
-- legacy API (Settings / Auto Play "AutoESP") now drives this layer
function RAVYN:SetESP(kind,v)
    if kind=="NPC" then return self:SetVisual("Mobs",v==true) elseif kind=="Boss" then return self:SetVisual("Bosses",v==true) end
    return result(false,"UNKNOWN_ESP_KIND")
end
V.token=V.token+1
local token=V.token
task.spawn(function()
    while not RAVYN._destroyed and V.token==token do
        local t=os.clock()
        local ok,err=pcall(step,t)
        if not ok then RAVYN.Logger:log("WARN","ESP_STEP",{error=tostring(err)}) end
        task.wait(anyOn() and .3 or 1)
    end
    clearAll()
end)
local baseDestroy=RAVYN.Destroy
function RAVYN:Destroy()
    V.token=V.token+1; clearAll()
    for _,f in ipairs({V.folder,V.hlFolder}) do if f then pcall(function() f:Destroy() end) end end
    V.folder=nil; V.hlFolder=nil
    return baseDestroy(self)
end
CTX["Visuals11"]=V
RAVYN.Logger:log("INFO","VISUALS_V11_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("BossLootV2.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Util=CTX["Util"]
local Config=CTX["Config"]
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local liveRoot=CTX["liveRoot"]
local requestTravel=CTX["requestTravel384"]
local pressKey=CTX["pressKey"]
local keyCodeFromText=CTX["keyCodeFromText"]
local P=CTX["JobPriority"]
local D=CTX["Direct11"]
-- RAVYN DIRECT v1.2 · BossLootController V2
-- Live evidence (UniversalTrace #001, Datai):
--   +113.2s NPC_DIED Datai [HealthZero]
--   +113.3s GUI ChestPrompt appears · KeyHolder...NoneHolding.TextLabel = "T"
--   +127.3s KEY T → +127.5s DATA.Progress.chests 197→198 → ChestPrompt removed → Workspace LootDrop (Common/Rare/Epic) appear
--   LootDropPrompt (key T, item name + "Claim") → KEY T → prompt removed → DATA.Inventory.<item>.Amount increases
-- Flow: death → wait ChestPrompt → press its key once → verify (chests counter or prompt gone) → wait drops →
-- collect every drop with its prompt key → verify (inventory / drop removed / prompt gone) → quiet rescan → finish.
-- Only the key the prompt itself displays is pressed. No remotes. fireproximityprompt is a fallback for a prompt
-- that stays unverified, on the ProximityPrompt that sits under the prompt's own Adornee.
local defaults={Enabled=true,ChestWait=6,ChestVerify=2.5,DropWait=4,DropVerify=1.6,MaxAttempts=3,QuietWindow=1.2,SessionTimeout=45,
    KeyFallback="T",UsePromptFallback=true,WatchChestPrompt=true}
Config.Default.BossLootV2=Util.deepCopy(defaults)
RAVYN.Config.BossLootV2=Util.deepMerge(defaults,RAVYN.Config.BossLootV2 or {})
local function bc() return RAVYN.Config.BossLootV2 end
local LC=RAVYN.LootController
local LP=game:GetService("Players").LocalPlayer

local B={token=0,holder=nil,holderAt=-math.huge,stats={sessions=0,chestsOpened=0,chestUnverified=0,items=0,unverified=0},lastItems={},lastKey=nil,phase="IDLE",verifiedBy=nil}
RAVYN.BossLootV2=B
local S=nil
local function exec(name) local f=(getgenv and getgenv()[name]) or G[name]; return type(f)=="function" and f or nil end
local function event(text,kind)
    if LC then table.insert(LC.events,{at=os.clock(),text=text,kind=kind or "info"}); while #LC.events>30 do table.remove(LC.events,1) end end
    RAVYN.Logger:log("INFO","LOOT · "..text,{})
end
local function posOf(inst)
    if not inst or not inst.Parent then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    if inst:IsA("Attachment") then return inst.WorldPosition end
    if inst:IsA("Model") then local ok,cf=pcall(function() return inst:GetPivot() end); if ok then return cf.Position end end
    local a=inst:FindFirstChild("Attachment2"); if a and a:IsA("Attachment") then return a.WorldPosition end
    local bp=inst:FindFirstChildWhichIsA("BasePart",true); return bp and bp.Position or nil
end

-- ---------------- prompt GUIs (PlayerGui.PromptsHolder.ChestPrompt / LootDropPrompt) ----------------
local function playerGui() return LP and LP:FindFirstChildOfClass("PlayerGui") end
local function promptsHolder(deep)
    if B.holder and B.holder.Parent then return B.holder end
    local pg=playerGui(); if not pg then return nil end
    local h=pg:FindFirstChild("PromptsHolder")
    if not h and deep and os.clock()-B.holderAt>3 then
        -- one bounded lookup (only inside a loot session) to learn where the prompt GUIs are parented
        B.holderAt=os.clock()
        local ok,c=pcall(function() return pg:FindFirstChild("ChestPrompt",true) or pg:FindFirstChild("LootDropPrompt",true) end)
        if ok and c then h=c.Parent end
    end
    if h then B.holder=h end
    return h or pg
end
local function shown(g)
    if not g or not g.Parent then return false end
    if g:IsA("LayerCollector") then if not g.Enabled then return false end
    elseif g:IsA("GuiObject") and not g.Visible then return false end
    local tb=g:FindFirstChild("TextButton")
    if tb and tb:IsA("GuiObject") and not tb.Visible then return false end
    return true
end
local function keyOf(g)
    local kh=g:FindFirstChild("KeyHolder",true)
    local lab=kh and kh:FindFirstChildWhichIsA("TextLabel",true)
    local t=lab and D.trim(lab.Text) or ""
    if t~="" and #t<=3 and keyCodeFromText(t) then return string.upper(t),"PROMPT_LABEL" end
    return bc().KeyFallback or "T","FALLBACK"
end
local function itemOf(g)
    local th=g:FindFirstChild("TextHolder",true)
    local lab=th and th:FindFirstChild("TextLabel")
    return lab and D.trim(lab.Text) or nil
end
local function adorneeOf(g)
    if g:IsA("BillboardGui") then local ok,a=pcall(function() return g.Adornee end); if ok and a then return a end end
    return nil
end
-- visible prompts of one kind, nearest first
local function prompts(name,deep)
    local h=promptsHolder(deep); local out={}
    if not h then return out end
    local root=liveRoot()
    for _,g in ipairs(h:GetChildren()) do
        if g.Name==name and shown(g) then
            local a=adorneeOf(g); local p=a and posOf(a)
            local k,src=keyOf(g)
            table.insert(out,{gui=g,adornee=a,pos=p,key=k,keySource=src,item=itemOf(g),dist=(p and root) and (root.Position-p).Magnitude or 0})
        end
    end
    table.sort(out,function(a,b) return a.dist<b.dist end)
    return out
end
-- another (non-loot) prompt showing the same key could steal the press (the trace shows a "Wall · Climb" prompt on T)
local function competingPrompt(key)
    local h=promptsHolder(false); if not h then return nil end
    for _,g in ipairs(h:GetChildren()) do
        if g.Name~="ChestPrompt" and g.Name~="LootDropPrompt" and shown(g) and g:FindFirstChild("KeyHolder",true) then
            local k=keyOf(g); if k==key then return itemOf(g) or g.Name end
        end
    end
    return nil
end

-- ---------------- local data (Player_Service.Data.<LocalPlayer>, active slot) ----------------
local function dataRoots()
    local SCH=RAVYN.RuntimeSchema; if not (SCH and SCH.get) then return {} end
    local s=SCH.get(); local n=s.nodes or {}
    return {n.sectionRoot,n.playerData}
end
local function chestsCounter()
    for _,r in ipairs(dataRoots()) do
        if r and r.Parent then
            local pr=r:FindFirstChild("Progress"); local v=pr and pr:FindFirstChild("chests")
            if v and v:IsA("ValueBase") then return tonumber(v.Value) end
        end
    end
    return nil
end
local function inventory()
    for _,r in ipairs(dataRoots()) do
        if r and r.Parent then
            local inv=r:FindFirstChild("Inventory")
            if inv then
                local out={}
                for i,it in ipairs(inv:GetChildren()) do
                    if i>800 then break end
                    local a=it:FindFirstChild("Amount")
                    if a and a:IsA("ValueBase") then out[it.Name]=tonumber(a.Value) or 0 end
                end
                return out
            end
        end
    end
    return nil
end
local function gained(before,after)
    local out={}
    if not (before and after) then return out end
    for k,v in pairs(after) do if v>(before[k] or 0) then table.insert(out,{name=k,delta=v-(before[k] or 0)}) end end
    return out
end
-- Workspace LootDrop objects (trace: WS.LootDrop.<Common|Rare|Epic>.Attachment2.start.Beam)
local function worldDrops()
    local out={}
    for _,c in ipairs(workspace:GetChildren()) do
        if c.Name=="LootDrop" then
            local nested=false
            for _,k in ipairs(c:GetChildren()) do if k:FindFirstChild("Attachment2") then nested=true; table.insert(out,k) end end
            if not nested and c:FindFirstChild("Attachment2") then table.insert(out,c) end
        end
    end
    return out
end
local function underPrompt(inst)
    if not inst then return nil end
    local ok,pp=pcall(function() return inst:FindFirstChildWhichIsA("ProximityPrompt",true) end)
    return ok and pp or nil
end

-- ---------------- session ----------------
local function publish()
    if not S then return end
    local det,col,unv=0,0,0
    for _,it in pairs(S.items) do det=det+1; if it.collected then col=col+1 end; if it.unverified then unv=unv+1 end end
    LC.detected=det; LC.collected=col; LC.unverified=unv; LC.attempted=det; LC.remaining=math.max(0,det-col-unv)
    LC.bossName=S.bossName; LC.expectedChest=S.chestName or "Boss chest"; LC.chestState=S.chestState; LC.chestInteraction="KEY "..tostring(B.lastKey or "?")
end
local function setPhase(ph,label)
    if S.phase~=ph then S.phase=ph; S.phaseAt=os.clock() end
    B.phase=ph; LC.state=label or ph
end
local function finish(code,kind)
    if not S then return end
    publish()
    local names={}; for _,g in ipairs(S.gainedAll) do table.insert(names,g.name..(g.delta>1 and (" ×"..g.delta) or "")) end
    local summary=string.format("%s%s · chest %s · %d/%d drops%s",S.bossName and (S.bossName.." · ") or "",code,S.chestState,LC.collected,LC.detected,
        #names>0 and (" · "..table.concat(names,", ")) or "")
    B.lastItems=names; LC.lastResult=summary; event(summary,kind or "success")
    S=nil; LC.active=false; LC.v2Active=false; LC.priority=0; LC.state="COMPLETE"; B.phase="IDLE"
    local sid=B.token
    task.delay(1.5,function() if B.token==sid and not LC.active then LC.state="IDLE" end end)
end
local function begin(kind,origin,ctx)
    B.token=B.token+1; B.stats.sessions=B.stats.sessions+1
    local now=os.clock()
    S={id=B.token,kind=kind,origin=D.toV3(origin),bossName=ctx and ctx.bossName,chestName=ctx and ctx.chest,startedAt=now,phase="",phaseAt=now,
        chestAttempts=0,chestFiredAt=-math.huge,chestState="WAITING",items={},gainedAll={},lastNewAt=now}
    LC.active=true; LC.v2Active=true; LC.kind="BOSS_V2"; LC.priority=(P and P.BOSS_LOOT) or 110; LC.failReason=nil; LC.probe=nil
    if D then D.bump("loot") end
    setPhase("WAIT_CHEST","WAITING_CHEST"); publish()
    event("Boss loot · "..tostring(S.bossName or kind).." · waiting for chest","info")
end
B.begin=begin

local function press(key,why)
    B.lastKey=key
    -- loot prompt key (not combat): declared LOOT scope for the v1.2.2 InputAudit
    local IA=RAVYN.InputAudit
    local ok,src
    if IA and IA.withScope then ok,src=IA.withScope("LOOT",pressKey,key) else ok,src=pressKey(key) end
    if not ok then LC.failReason="INPUT_UNAVAILABLE" end
    return ok,src
end
local function chestStep(now,root)
    local list=prompts("ChestPrompt",true); local cp=list[1]
    if S.phase=="WAIT_CHEST" then
        if cp then setPhase("OPEN_CHEST","OPENING"); return end
        if #worldDrops()>0 and now-S.phaseAt>1 then S.chestState="NOT_SHOWN"; setPhase("WAIT_DROPS","DETECTING_DROPS"); return end
        if now-S.phaseAt>(bc().ChestWait or 6) then S.chestState="NOT_SHOWN"; setPhase("WAIT_DROPS","DETECTING_DROPS"); return end
        -- the prompt only shows inside its range: after 1.5 s move to where the boss died
        if now-S.phaseAt>1.5 and S.origin and (root.Position-S.origin).Magnitude>6 and requestTravel then
            requestTravel(S.origin+Vector3.new(0,3,0),"BOSS CHEST","v2chest:"..S.id,.5)
        end
        return
    end
    -- OPEN_CHEST
    if S.chestAttempts>0 then
        local c=chestsCounter()
        local byCounter=(S.chestsBefore~=nil and c~=nil and c>S.chestsBefore)
        if byCounter or not cp then
            S.chestState="OPEN_VERIFIED"; B.verifiedBy=byCounter and "CHESTS_COUNTER" or "PROMPT_GONE"
            B.stats.chestsOpened=B.stats.chestsOpened+1
            event("Chest opened · verified by "..(byCounter and ("chests "..tostring(S.chestsBefore).."→"..tostring(c)) or "prompt disappearing"),"success")
            setPhase("WAIT_DROPS","DETECTING_DROPS"); return
        end
    elseif not cp then
        if now-S.phaseAt>2 then setPhase("WAIT_CHEST","WAITING_CHEST") end
        return
    end
    if cp.pos and cp.dist>9 and requestTravel then requestTravel(cp.pos+Vector3.new(0,2.5,0),"BOSS CHEST","v2chest:"..S.id,.5); return end
    local due=S.chestAttempts==0 or now-S.chestFiredAt>(bc().ChestVerify or 2.5)
    if not due then return end
    if S.chestAttempts>=(bc().MaxAttempts or 3) then
        -- last resort on the chest's own ProximityPrompt, then give up honestly
        local pp=bc().UsePromptFallback and underPrompt(cp.adornee)
        local f=exec("fireproximityprompt")
        if pp and f and not S.chestFallback then
            S.chestFallback=true; S.chestFiredAt=now; pcall(function() f(pp,math.max(pp.HoldDuration or 0,0)) end); return
        end
        S.chestState="OPEN_UNVERIFIED"; B.stats.chestUnverified=B.stats.chestUnverified+1; LC.failReason="CHEST_OPEN_UNVERIFIED"
        event("Chest key sent "..S.chestAttempts.."× but no counter/prompt change","warn")
        setPhase("WAIT_DROPS","DETECTING_DROPS"); return
    end
    local rival=competingPrompt(cp.key)
    if rival and S.chestAttempts==0 and cp.pos and requestTravel then
        -- step onto the chest so its prompt is the closest one for this key
        requestTravel(cp.pos+Vector3.new(0,2,0),"BOSS CHEST","v2chest-exact:"..S.id,.4)
    end
    S.chestsBefore=chestsCounter()
    press(cp.key,"CHEST")
    S.chestAttempts=S.chestAttempts+1; S.chestFiredAt=now; S.chestState="OPEN_SENT"
end
local function collectStep(now,root)
    -- register targets: world LootDrop objects + adornees of visible LootDropPrompts
    for _,inst in ipairs(worldDrops()) do
        if not S.items[inst] then S.items[inst]={inst=inst,attempts=0}; S.lastNewAt=now end
    end
    local lp=prompts("LootDropPrompt",true)
    for _,p in ipairs(lp) do
        if p.adornee and not S.items[p.adornee] then
            local known=false
            for inst in pairs(S.items) do if inst==p.adornee or (typeof(inst)=="Instance" and p.adornee:IsDescendantOf(inst)) then known=true; break end end
            if not known then S.items[p.adornee]={inst=p.adornee,attempts=0}; S.lastNewAt=now end
        end
    end
    -- resolve pending verification / gone drops
    local pending=nil; local nearest,nd=nil,math.huge
    for inst,it in pairs(S.items) do
        if not it.collected and not it.unverified and not it.gone then
            if it.pending then
                local after=inventory(); local g=gained(it.pending.inv,after)
                local removed=not inst.Parent
                local promptGone=it.pending.item and (function() for _,p in ipairs(prompts("LootDropPrompt",false)) do if p.item==it.pending.item then return false end end; return true end)() or false
                if #g>0 or removed or promptGone then
                    it.collected=true; it.pending=nil; B.stats.items=B.stats.items+1
                    for _,x in ipairs(g) do table.insert(S.gainedAll,x) end
                    it.evidence=(#g>0 and "INVENTORY") or (removed and "DROP_REMOVED") or "PROMPT_GONE"
                elseif now-it.firedAt>(bc().DropVerify or 1.6) then
                    it.pending=nil
                    if it.attempts>=(bc().MaxAttempts or 3) then it.unverified=true; B.stats.unverified=B.stats.unverified+1 end
                else pending=it end
            elseif not inst.Parent then
                it.gone=true -- despawned before we reached it (not counted as collected)
            else
                local p=posOf(inst); it.pos=p or it.pos
                local d=(p and (root.Position-p).Magnitude) or math.huge
                if d<nd then nearest,nd=it,d end
            end
        end
    end
    publish()
    if pending then LC.state=string.format("VERIFYING %d / %d",LC.collected,LC.detected); return true end
    if not nearest then return false end
    LC.state=string.format("COLLECTING %d / %d",LC.collected,LC.detected)
    if nd>5 and nearest.pos and requestTravel then
        nearest.arrivedAt=nil
        requestTravel(nearest.pos+Vector3.new(0,2,0),"LOOT","v2drop:"..S.id..":"..tostring(nearest.inst),.5)
        return true
    end
    nearest.arrivedAt=nearest.arrivedAt or now
    local shownNow=prompts("LootDropPrompt",false)[1]
    if shownNow and now-nearest.arrivedAt>=.15 then
        local rival=competingPrompt(shownNow.key)
        if rival and nearest.attempts==0 and nearest.pos and requestTravel then
            requestTravel(nearest.pos+Vector3.new(0,1,0),"LOOT","v2drop-exact:"..S.id..":"..tostring(nearest.inst),.4)
        end
        nearest.pending={inv=inventory(),item=shownNow.item}
        press(shownNow.key,"DROP")
        nearest.attempts=nearest.attempts+1; nearest.firedAt=now
        return true
    end
    if not shownNow and now-nearest.arrivedAt>1.5 then
        -- standing on the drop but no prompt shows: its own ProximityPrompt is the only other real affordance
        local pp=bc().UsePromptFallback and underPrompt(nearest.inst); local f=exec("fireproximityprompt")
        nearest.attempts=nearest.attempts+1; nearest.arrivedAt=now
        if pp and f then
            nearest.pending={inv=inventory(),item=nil}; nearest.firedAt=now
            pcall(function() f(pp,math.max(pp.HoldDuration or 0,0)) end)
        elseif nearest.attempts>=(bc().MaxAttempts or 3) then
            nearest.unverified=true; B.stats.unverified=B.stats.unverified+1; LC.failReason="NO_PROMPT_SHOWN"
        end
    end
    return true
end
local function tick()
    local now=os.clock()
    if not S then
        -- watcher: a ChestPrompt showing with no session (mini bosses, world chests) starts one — cheap direct-child check
        if bc().Enabled and bc().WatchChestPrompt and D.running() and not LC.active and RAVYN.Config.Loot384.AutoLootChests then
            local h=promptsHolder(false); local cp=h and h:FindFirstChild("ChestPrompt")
            if cp and shown(cp) then local root=liveRoot(); begin("CHEST_PROMPT",root and root.Position,nil) end
        end
        return
    end
    if not D.running() then S=nil; LC.v2Active=false; LC.active=false; LC.state="IDLE"; return end
    local root=liveRoot(); if not root then return end
    if now-S.startedAt>(bc().SessionTimeout or 45) then finish("LOOT_TIMEOUT","warn"); return end
    if S.phase=="WAIT_CHEST" or S.phase=="OPEN_CHEST" then chestStep(now,root); publish(); return end
    local busy=collectStep(now,root)
    if S.phase=="WAIT_DROPS" then
        if busy then setPhase("COLLECT",LC.state)
        elseif now-S.phaseAt>(bc().DropWait or 4) then setPhase("QUIET","RESCAN") end
        return
    end
    if S.phase=="COLLECT" and not busy then setPhase("QUIET","RESCAN"); return end
    if S.phase=="QUIET" then
        if busy then setPhase("COLLECT",LC.state); return end
        if now-S.phaseAt>=(bc().QuietWindow or 1.2) and now-S.lastNewAt>=(bc().QuietWindow or 1.2) then
            local warn=S.chestState=="OPEN_UNVERIFIED" or LC.unverified>0
            finish(LC.detected==0 and "NO_DROPS" or "LOOT COMPLETE",warn and "warn" or "success")
        end
    end
end

-- boss kills route to V2 (normal mob kills keep the v3.8.4.2 path)
local baseStart=RAVYN.StartKillLoot
function RAVYN:StartKillLoot(pos,isBoss,baseline,quest,ctx)
    if isBoss and bc().Enabled and self.Config.Loot384.AutoLootAfterKill then
        if S then return result(false,"LOOT_BUSY") end
        if LC.active and not LC.v2Active then return baseStart(self,pos,isBoss,baseline,quest,ctx) end
        begin("BOSS",pos,ctx)
        return result(true,"LOOT_SESSION_STARTED",{kind="BOSS_V2"})
    end
    return baseStart(self,pos,isBoss,baseline,quest,ctx)
end
function RAVYN:GetBossLootV2Status()
    return result(true,"BOSS_LOOT_V2",{phase=B.phase,chest=S and S.chestState,stats=B.stats,lastItems=B.lastItems,key=B.lastKey,verifiedBy=B.verifiedBy,chests=chestsCounter()})
end
B.chestsCounter=chestsCounter

-- capability provider: promote exactly what the trace established
local GK=RAVYN.GameKnowledge
if GK and GK.capabilities then
    local ev="Trace #001: Datai HealthZero → ChestPrompt (key T) → T → Progress.chests 198 → LootDrop; LootDropPrompt T → Inventory Amount"
    if GK.capabilities.BOSS_CHEST_OPEN then GK.capabilities.BOSS_CHEST_OPEN.status="PARTIAL"; GK.capabilities.BOSS_CHEST_OPEN.evidence=ev end
    if GK.capabilities.DROP_COLLECTION then GK.capabilities.DROP_COLLECTION.status="PARTIAL"; GK.capabilities.DROP_COLLECTION.evidence=ev end
end

B.loop=(B.loop or 0)+1
local mine=B.loop
task.spawn(function()
    while not RAVYN._destroyed and B.loop==mine do
        local ok,err=pcall(tick)
        if not ok then RAVYN.Logger:log("ERROR","BOSS_LOOT_V2_TICK",{error=tostring(err)}); if S then pcall(finish,"LOOT_ERROR","warn") end end
        task.wait(S and .15 or .3)
    end
end)
local baseStop=RAVYN.Stop
function RAVYN:Stop() S=nil; B.token=B.token+1; LC.v2Active=false; B.phase="IDLE"; return baseStop(self) end
local baseDestroy=RAVYN.Destroy
function RAVYN:Destroy() B.loop=B.loop+1; S=nil; LC.v2Active=false; B.holder=nil; return baseDestroy(self) end
CTX["BossLootV2"]=B
RAVYN.Logger:log("INFO","BOSS_LOOT_V2_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("OuwiReaderV12.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Util=CTX["Util"]
local Config=CTX["Config"]
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local DG=CTX["Dungeon11"]
-- RAVYN DIRECT v1.2 · OuwigaharaStateReader (dynamic, no trace yet).
-- Only while Dungeon mode is ON: search PlayerGui ONCE (bounded, ≤ every 5 s until found) for semantic text —
-- Floor · Points · Enemies remaining · Rerolls · card title/description/button groups — cache the ScreenGui that
-- holds them, then read ONLY that cached root (1 Hz). No card list is hard-coded: cards are recognised by
-- structure (≥2 sibling panels, each with a button and ≥2 texts); preference names are only a hint.
-- Card clicking stays locked until a card set was actually discovered at runtime, and then it is verified.
Config.Default.Ouwi11.Enabled=false
if type(RAVYN.Config.Ouwi11.Enabled)~="boolean" then RAVYN.Config.Ouwi11.Enabled=false end
local LP=game:GetService("Players").LocalPlayer
local R={status="OFF",detail="",root=nil,rootPath=nil,cardRoot=nil,discoverAt=-math.huge,cardAt=-math.huge,readAt=-math.huge,
    floor=nil,points=nil,enemies=nil,rerolls=nil,cards={},ranked={},hits={},cardsSeen=false,clicks=0,clickVerified=0,clickFails=0,pendingClick=nil}
DG.reader=R
local VIM=game:GetService("VirtualInputManager")
local function low(v) return string.lower(tostring(v or "")) end
local function trim(v) v=tostring(v or ""); v=string.gsub(v,"<.->",""); v=string.gsub(v,"^%s+",""); v=string.gsub(v,"%s+$",""); return v end
local function num(s) if not s then return nil end; s=string.gsub(s,",",""); return tonumber(s) end
local function visibleChain(g,stop)
    local cur=g
    for _=1,25 do
        if not cur or cur==stop then return true end
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("LayerCollector") and not cur.Enabled then return false end
        cur=cur.Parent
    end
    return true
end
-- semantic patterns → kind, value
local function classify(text)
    local t=low(trim(text))
    if t=="" or #t>80 then return nil end
    local v=string.match(t,"floor%s*[:#]?%s*(%d+)"); if v then return "floor",num(v) end
    if string.match(t,"^floor") then return "floor",nil end
    v=string.match(t,"enem[%a]*%s*remaining%s*[:]?%s*(%d+)") or string.match(t,"(%d+)%s*enem[%a]*%s*remaining") or string.match(t,"enem[%a]*%s*left%s*[:]?%s*(%d+)") or string.match(t,"(%d+)%s*enem[%a]*%s*left")
    if v then return "enemies",num(v) end
    if string.find(t,"enemies remaining",1,true) then return "enemies",nil end
    v=string.match(t,"rerolls?%s*[:]?%s*(%d+)") or string.match(t,"(%d+)%s*rerolls?"); if v then return "rerolls",num(v) end
    if string.find(t,"reroll",1,true) then return "rerolls",nil end
    v=string.match(t,"points?%s*[:]?%s*([%d,]+)") or string.match(t,"([%d,]+)%s*points?"); if v then return "points",num(v) end
    if string.find(t,"points",1,true) then return "points",nil end
    return nil
end
local function layerOf(g) local cur=g; while cur and not cur:IsA("LayerCollector") do cur=cur.Parent end; return cur end
local function prefNames()
    local d=RAVYN.Config.Dungeon; local set={}
    for _,l in ipairs({d.Blacklist or {},d.PriorityOrder or {},d.LowPriority or {}}) do for _,n in ipairs(l) do set[low(n)]=true end end
    for n in pairs(d.Weights or {}) do set[low(n)]=true end
    return set
end
-- one bounded PlayerGui pass: pick the ScreenGui with the most distinct dungeon HUD kinds
local function discover(now)
    if now-R.discoverAt<5 then return end
    R.discoverAt=now
    local pg=LP and LP:FindFirstChildOfClass("PlayerGui"); if not pg then return end
    local own=RAVYN._gui
    local ok,desc=pcall(function() return pg:GetDescendants() end); if not ok then return end
    local score={}; local hints={}
    for i,d in ipairs(desc) do
        if i>8000 then break end
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and not (own and d:IsDescendantOf(own)) then
            local kind=classify(d.Text)
            local lg=layerOf(d)
            if kind and lg then score[lg]=score[lg] or {}; score[lg][kind]=true end
            local t=low(d.Text)
            if lg and (string.find(t,"card",1,true) or string.find(t,"choose",1,true) or string.find(t,"select",1,true) or string.find(t,"reroll",1,true)) then hints[lg]=true end
        end
    end
    local best,bn=nil,0
    for lg,kinds in pairs(score) do
        local n=0; for _ in pairs(kinds) do n=n+1 end
        -- a lone "points" label (skill points, etc.) is not a dungeon HUD: need 2 kinds, or Floor / Enemies remaining
        local strong=n>=2 or kinds.floor or kinds.enemies
        if strong and n>bn then best,bn=lg,n end
    end
    R.root=best; R.rootPath=best and best:GetFullName() or nil; R.kindsFound=bn
    R.cardHints=hints
end
-- card set = container with ≥2 visible children, each holding a GuiButton and ≥2 non-empty texts
local function cardPanel(c,stop)
    local texts={}; local btn=c:IsA("GuiButton") and c or nil
    local ok,desc=pcall(function() return c:GetDescendants() end); if not ok then return nil end
    for i,d in ipairs(desc) do
        if i>60 then break end
        if not btn and d:IsA("GuiButton") then btn=d end
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and visibleChain(d,stop) then
            local t=trim(d.Text); if t~="" then table.insert(texts,{t=t,name=low(d.Name),size=d.TextSize or 0}) end
        end
    end
    if not btn or #texts<2 then return nil end
    local title=nil
    for _,x in ipairs(texts) do if string.find(x.name,"title",1,true) or x.name=="name" or string.find(x.name,"cardname",1,true) then title=x.t; break end end
    if not title then
        table.sort(texts,function(a,b) return a.size>b.size end)
        for _,x in ipairs(texts) do if #x.t<=32 and not tonumber(x.t) then title=x.t; break end end
    end
    local desc2=""; for _,x in ipairs(texts) do if #x.t>#desc2 and x.t~=title then desc2=x.t end end
    return title and {title=title,desc=desc2,button=btn,panel=c} or nil
end
local function discoverCards(now)
    if now-R.cardAt<3 then return end
    R.cardAt=now
    local roots={}
    if R.root and R.root.Parent then roots[R.root]=true end
    for lg in pairs(R.cardHints or {}) do if lg.Parent then roots[lg]=true end end
    local prefs=prefNames()
    for lg in pairs(roots) do
        local ok,desc=pcall(function() return lg:GetDescendants() end)
        if ok then
            for i,d in ipairs(desc) do
                if i>3000 then break end
                if d:IsA("GuiObject") and d.Visible and visibleChain(d,lg) then
                    local kids=d:GetChildren()
                    if #kids>=2 and #kids<=8 then
                        local cards={}; local prefHit=false
                        for _,c in ipairs(kids) do
                            if c:IsA("GuiObject") and c.Visible then
                                local card=cardPanel(c,lg)
                                if card then table.insert(cards,card); if prefs[low(card.title)] then prefHit=true end end
                            end
                        end
                        if #cards>=2 and (prefHit or (R.cardHints or {})[lg]) then R.cardRoot=d; R.cardsSeen=true; return end
                    end
                end
            end
        end
    end
end
local function readRoot()
    local vals={}; R.hits={}
    local ok,desc=pcall(function() return R.root:GetDescendants() end); if not ok then return end
    for i,d in ipairs(desc) do
        if i>1500 then break end
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and visibleChain(d,R.root) then
            local kind,v=classify(d.Text)
            if kind then
                R.hits[kind]=trim(d.Text)
                if v~=nil and vals[kind]==nil then vals[kind]=v end
                -- label/value split ("Floor" label + "12" sibling)
                if v==nil and d.Parent then
                    for _,s in ipairs(d.Parent:GetChildren()) do
                        if s~=d and (s:IsA("TextLabel") or s:IsA("TextButton")) then local n=num(string.match(trim(s.Text),"^([%d,]+)")); if n and vals[kind]==nil then vals[kind]=n end end
                    end
                end
            end
        end
    end
    R.floor=vals.floor; R.points=vals.points; R.enemies=vals.enemies; R.rerolls=vals.rerolls
end
local function readCards()
    R.cards={}
    if not (R.cardRoot and R.cardRoot.Parent and R.cardRoot.Visible and visibleChain(R.cardRoot,nil)) then R.cardRoot=nil; R.ranked={}; return end
    for _,c in ipairs(R.cardRoot:GetChildren()) do
        if c:IsA("GuiObject") and c.Visible then local card=cardPanel(c,R.cardRoot); if card then table.insert(R.cards,card) end end
    end
    local names={}; for _,c in ipairs(R.cards) do table.insert(names,c.title) end
    R.ranked=DG.rank(names)
end
-- runtime-discovered card set → card selection becomes a PARTIAL (verified) action
local function cardSub() for _,s in ipairs(DG.sub) do if s.key=="AutoSelectCards" then return s end end end
local function clickCenter(btn)
    local ok,p,s=pcall(function() return btn.AbsolutePosition,btn.AbsoluteSize end)
    if not ok or s.X<2 or s.Y<2 then return false end
    local x=math.floor(p.X+s.X*.5); local y=math.floor(p.Y+s.Y*.5)
    local IA=RAVYN.InputAudit; if IA and IA.note then IA.note("MOUSE","dungeon card","DUNGEON") end
    return pcall(function() VIM:SendMouseButtonEvent(x,y,0,true,game,0); task.wait(.025); VIM:SendMouseButtonEvent(x,y,0,false,game,0) end)
end
local function cardStep(now)
    local s=cardSub(); if not s then return end
    if R.cardsSeen and s.status=="UNAVAILABLE" then s.status="PARTIAL"; s.why="Card GUI discovered this session · clicks are verified" end
    if R.pendingClick then
        local p=R.pendingClick
        local gone=not (p.root and p.root.Parent and p.root.Visible) or #R.cards==0
        if gone then R.clickVerified=R.clickVerified+1; R.clickFails=0; R.pendingClick=nil; R.lastPick=p.title
        elseif now-p.at>2.5 then
            R.pendingClick=nil; R.clickFails=R.clickFails+1
            if R.clickFails>=2 then RAVYN.Config.Ouwi11.AutoSelectCards=false; s.status="UNVERIFIED"; s.why="Card click did not close the card choice · disabled"; R.detail=s.why end
        end
        return
    end
    if not (RAVYN.Config.Ouwi11.AutoSelectCards and s.status=="PARTIAL") or #R.ranked==0 then return end
    local best=R.ranked[1]; if not best or best.score==-math.huge then return end
    for _,c in ipairs(R.cards) do
        if c.title==best.name then
            if clickCenter(c.button) then R.clicks=R.clicks+1; R.pendingClick={at=now,title=c.title,root=R.cardRoot} end
            return
        end
    end
end
local function tick(now)
    if not RAVYN.Config.Ouwi11.Enabled then
        R.status="OFF"; R.detail="Dungeon mode off"; R.root=nil; R.cardRoot=nil; R.cards={}; R.ranked={}; return
    end
    if not (R.root and R.root.Parent) then R.root=nil; discover(now) end
    if not (R.cardRoot and R.cardRoot.Parent) then discoverCards(now) end
    if now-R.readAt>=1 then
        R.readAt=now
        if R.root then readRoot() end
        readCards()
    end
    pcall(cardStep,now)
    if R.root or R.cardRoot then R.status="READY"; R.detail=R.pendingClick and R.detail or ("Reading "..tostring(R.rootPath or "card panel"))
    else R.status="SEARCHING"; R.detail="No dungeon HUD found yet (not in Ouwigahara?)" end
end
function RAVYN:SetDungeonMode(v)
    if type(v)~="boolean" then return result(false,"INVALID_CONFIG") end
    R.discoverAt=-math.huge; R.cardAt=-math.huge
    return self:SetConfig("Ouwi11.Enabled",v)
end
function RAVYN:RediscoverDungeonHud() R.root=nil; R.cardRoot=nil; R.discoverAt=-math.huge; R.cardAt=-math.huge; return result(true,"REDISCOVER") end
R.token=(R.token or 0)+1
local token=R.token
task.spawn(function()
    while not RAVYN._destroyed and R.token==token do
        local ok,err=pcall(tick,os.clock())
        if not ok then RAVYN.Logger:log("WARN","OUWI_READER_TICK",{error=tostring(err)}) end
        task.wait(RAVYN.Config.Ouwi11.Enabled and .5 or 2)
    end
end)
local baseDestroy=RAVYN.Destroy
function RAVYN:Destroy() R.token=R.token+1; R.root=nil; R.cardRoot=nil; return baseDestroy(self) end
CTX["OuwiReader12"]=R
RAVYN.Logger:log("INFO","OUWI_READER_V12_READY")
return true]==========]); if not ok then return end end
do local ok=runChunk("CombatActionBusV122.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Util=CTX["Util"]
local Config=CTX["Config"]
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local liveRoot=CTX["liveRoot"]
local liveHumanoid=CTX["liveHumanoid"]
local targetBasis=CTX["targetBasis"]
local currentSkillKeys=CTX["currentSkillKeys"]
local idleLike=CTX["idleLike"]
local resolveGuardKey=CTX["resolveGuardKey"]
local evoCfg=CTX["evoCfg"]
local D=CTX["Direct11"]
-- The raw physical combat primitives are captured HERE ONLY and are called ONLY by LegacyCombatAdapter below.
local rawPressKey=CTX["pressKey"]
local rawMouse=CTX["fixedMouseButton"]
local rawKeyState=CTX["setKeyState"]
local rawDodge=CTX["legacyDirectionalDodge"]
-- RAVYN DIRECT v1.2.2 · Silent Combat
--
--   CombatBrain (CombatMobility · CombatEvolution · Smart Skills · InstaKillAdapter)
--     → RAVYN.CombatActionBus          one execution authority, action state machine, gates, counters
--       → ActionResolver               SilentActionAdapter.resolve(): finds EXISTING local game actions
--         → SilentActionAdapter        invokes a verified local game action (backend SILENT_LOCAL)
--         → LegacyCombatAdapter        key / mouse simulation (backend LEGACY_INPUT) · HYBRID / LEGACY_INPUT only
--
-- A silent binding is an action the game itself already exposes on this client:
--   · a ContextActionService action the game bound (ContextActionService:CallFunction on the game's own handler)
--   · a callback the game's own UI connected to one of its buttons (fired with firesignal / the connection itself)
--   · Tool:Activate() on the equipped tool
-- Listed only, never invoked (arguments / signatures unknown): BindableEvents/Functions, functions found in the game's _G/shared.
-- Never used: RemoteEvents/RemoteFunctions, require() of game modules, UserInputService handlers with fabricated
-- InputObjects, VirtualInputManager / VirtualUser / keypress / mouse1press. A binding becomes VERIFIED_SILENT only after
-- the game produced local evidence (own animation, own damage counter, skill cooldown GUI, displacement) for it.
-- SILENT mode executes VERIFIED_SILENT bindings only and never falls back to input simulation.

local Players=game:GetService("Players")
local LP=Players.LocalPlayer
local function exec(name) local f=(getgenv and getgenv()[name]) or G[name]; return type(f)=="function" and f or nil end

-- ================= config =================
local MODES={SILENT=true,HYBRID=true,LEGACY_INPUT=true}
Config.Default.CombatInputMode="SILENT"
if not MODES[RAVYN.Config.CombatInputMode] then RAVYN.Config.CombatInputMode="SILENT" end
local scDefaults={VerifyConfirmations=2,MaxCandidates=3,DemoteAfterNoEvidence=4,Verified={}}
Config.Default.SilentCombat=Util.deepCopy(scDefaults)
RAVYN.Config.SilentCombat=Util.deepMerge(scDefaults,RAVYN.Config.SilentCombat or {})
local validateBaseV122=Config.validate
function Config.validate(c)
    local _,errors=validateBaseV122(c)
    errors=errors or {}
    if c.CombatInputMode~=nil and not MODES[c.CombatInputMode] then table.insert(errors,"CombatInputMode") end
    return #errors==0,errors
end
local function scfg() return RAVYN.Config.SilentCombat end

-- ================= evidence (all local reads; nothing is sent) =================
local EV={}
local ACTION_WORDS={"block","guard","parry","dash","dodge","roll","attack","skill","cast","combo","action","heavy","evade","counter"}
local function actionWord(s) s=string.lower(tostring(s or "")); for _,w in ipairs(ACTION_WORDS) do if string.find(s,w,1,true) then return true end end; return false end
-- locomotion / ambient tracks are never evidence of a combat action
local AMBIENT={"idle","walk","run","jump","fall","land","breath","stand","locomotion","climb","swim","sit","toolnone","emote","dance","wave","cheer","laugh","point"}
local function isIdle(name)
    local l=string.lower(tostring(name or ""))
    for _,w in ipairs(AMBIENT) do if string.find(l,w,1,true) then return true end end
    if idleLike then local ok,v=pcall(idleLike,name); if ok and v then return true end end
    return false
end
function EV.tracks()
    local out={}
    local h=liveHumanoid(); if not h then return out end
    local ok,an=pcall(function() return h:FindFirstChildOfClass("Animator") end)
    if not ok or not an then return out end
    local ok2,list=pcall(function() return an:GetPlayingAnimationTracks() end)
    if not ok2 or type(list)~="table" then return out end
    for i,tr in ipairs(list) do
        if i>24 then break end
        local ok3,id,name,tp,looped=pcall(function() local a=tr.Animation; return a and a.AnimationId or "",a and a.Name or "",tr.TimePosition,tr.Looped end)
        if ok3 then out[tr]={id=tostring(id or ""),name=tostring(name or ""),tp=tonumber(tp) or 0,looped=looped==true} end
    end
    return out
end
function EV.targetHum(target)
    local RA=RAVYN.ReadAdapter; local raw=RA and RA.lastEntities and target and target.id and RA.lastEntities[target.id]
    if not raw then return nil end
    local ok,h=pcall(function() return RA:_entityHumanoid(raw) end)
    return ok and h or nil
end
function EV.hpFrac(h)
    if not h then return nil end
    local ok,hp,mx=pcall(function() return h.Health,h.MaxHealth end)
    if ok and tonumber(hp) and tonumber(mx) and mx>0 then return hp/mx,hp,mx end
    return nil
end
local progressAt,progressNode=-math.huge,nil
function EV.progress()
    if progressNode and progressNode.Parent then return progressNode end
    local now=os.clock(); if now-progressAt<5 then return nil end; progressAt=now
    local SCH=RAVYN.RuntimeSchema; if not (SCH and SCH.get) then return nil end
    local ok,s=pcall(SCH.get); local n=(ok and s and s.nodes) or {}
    for _,r in ipairs({n.sectionRoot,n.playerData}) do
        if r and r.Parent then local p=r:FindFirstChild("Progress"); if p then progressNode=p; return p end end
    end
    return nil
end
function EV.damageDealt()
    local p=EV.progress(); local v=p and p:FindFirstChild("damage_dealt")
    if v and v:IsA("ValueBase") then return tonumber(v.Value) end
    return nil
end
function EV.slot(index)
    local pg=LP and LP:FindFirstChildOfClass("PlayerGui"); local a=pg and pg:FindFirstChild("ComponentsHolder")
    a=a and a:FindFirstChild("BottomHolder"); a=a and a:FindFirstChild("SkillsHolder")
    return a and a:FindFirstChild(tostring(index).."-Skill") or nil
end
function EV.slotSig(index)
    local slot=EV.slot(index); if not slot then return nil end
    local ok,desc=pcall(function() return slot:GetDescendants() end); if not ok then return nil end
    local out={}
    for i,d in ipairs(desc) do
        if i>80 then break end
        if d:IsA("GuiObject") and d.Name~="KeyLabel" then
            local s=d.Name..(d.Visible and "1" or "0")..string.format("%.2f,%.2f",d.Size.X.Scale,d.Size.Y.Scale)..string.format("%.2f",d.BackgroundTransparency)
            if d:IsA("ImageLabel") or d:IsA("ImageButton") then s=s..string.format("i%.2f",d.ImageTransparency) end
            if d:IsA("TextLabel") or d:IsA("TextButton") then s=s.."t"..string.sub(d.Text,1,12) end
            table.insert(out,s)
        end
    end
    return table.concat(out,"|")
end
function EV.attrs()
    local h=liveHumanoid(); local out={}
    if not h then return out end
    for tag,o in pairs({C=h.Parent,H=h}) do
        if o then
            local ok,a=pcall(function() return o:GetAttributes() end)
            if ok and type(a)=="table" then for k,v in pairs(a) do local t=type(v); if t=="boolean" or t=="number" or t=="string" then out[tag.."."..tostring(k)]=v end end end
        end
    end
    return out
end
function EV.snap(cap,target,skill)
    local s={cap=cap,at=os.clock(),tracks=EV.tracks(),dmg=EV.damageDealt()}
    local h=EV.targetHum(target)
    if h then local ok,hp=pcall(function() return h.Health end); if ok and tonumber(hp) then s.hum=h; s.hp=tonumber(hp) end end
    if skill and skill.index then s.slotIndex=skill.index; s.slot=EV.slotSig(skill.index) end
    if cap=="GUARD" or cap=="PARRY" then s.attrs=EV.attrs() end
    if cap=="DASH" then local r=liveRoot(); s.pos=r and r.Position end
    return s
end
function EV.evaluate(s)
    local ev={}
    for tr,info in pairs(EV.tracks()) do
        if not isIdle(info.name) then
            local old=s.tracks[tr]
            if not old then ev.ANIMATION=(info.name~="" and info.name) or info.id; break end
            -- a restarted one-shot track (looped tracks wrap on their own and prove nothing)
            if not info.looped and info.tp+.05<old.tp then ev.ANIMATION_RESTART=(info.name~="" and info.name) or info.id; break end
        end
    end
    if s.hum and s.hp then local ok,hp=pcall(function() return s.hum.Health end); hp=ok and tonumber(hp) or nil; if hp and hp<s.hp then ev.TARGET_HP=s.hp-hp end end
    if s.dmg then local d=EV.damageDealt(); if d and d>s.dmg then ev.DAMAGE_DEALT=d-s.dmg end end
    if s.slotIndex and s.slot then local sig=EV.slotSig(s.slotIndex); if sig and sig~=s.slot then ev.SLOT_COOLDOWN=true end end
    if s.pos then
        local r=liveRoot(); local M=RAVYN.CombatMobility
        if r and not (M and M.flightActive) then local d=(r.Position-s.pos).Magnitude; if d>=4 then ev.DISPLACEMENT=d end end
    end
    if s.attrs then for k,v in pairs(EV.attrs()) do if s.attrs[k]~=v and (type(v)=="boolean" or actionWord(k)) then ev.STATE_ATTR=k; break end end end
    return ev
end
local EVIDENCE_ORDER={"SLOT_COOLDOWN","DAMAGE_DEALT","TARGET_HP","ANIMATION","ANIMATION_RESTART","DISPLACEMENT","STATE_ATTR"}
-- evidence that can only come from THIS client's own action (TARGET_HP alone could be another player's hit)
local LOCAL_EVIDENCE={SLOT_COOLDOWN=true,DAMAGE_DEALT=true,ANIMATION=true,ANIMATION_RESTART=true,DISPLACEMENT=true,STATE_ATTR=true}
function EV.first(ev) for _,k in ipairs(EVIDENCE_ORDER) do if ev[k]~=nil then return k end end; return nil end
function EV.text(ev) local t={}; for _,k in ipairs(EVIDENCE_ORDER) do if ev[k]~=nil then table.insert(t,k) end end; return table.concat(t,"+") end
function EV.localOnly(ev) for k in pairs(LOCAL_EVIDENCE) do if ev[k]~=nil then return true end end; return false end
RAVYN.CombatEvidence=EV

-- ================= bus state (defined first: the audit and both adapters report into it) =================
local B={seq=0,execCount=0,silentCount=0,legacyCount=0,finisherCount=0,testExecs=0,rejects={},lastReject=nil,
    fight=nil,lastFight=nil,guardDown=false,guardAt=0,guardBackend=nil,guardBinding=nil,guardKey=nil,defenseUntil=0,
    cooldown={},dmg={},pendingDmg=nil,token=0,history={},lastAction=nil,modeChangedAt=0}
local CH={OFFENSE={name="OFFENSE",state="READY",current=nil,lockUntil=0,readyAt=0,last=nil},
    DEFENSE={name="DEFENSE",state="READY",current=nil,lockUntil=0,readyAt=0,last=nil}}
B.ch=CH
RAVYN.CombatActionBus=B
function B.mode() local m=RAVYN.Config.CombatInputMode; return MODES[m] and m or "SILENT" end

-- ================= InputAudit: every physical input RAVYN makes is scoped, counted and (for combat) gated =================
-- Each RAVYN physical-input primitive calls A.physical() before it injects anything.
--   LEGACY_COMBAT  : LegacyCombatAdapter · allowed in HYBRID / LEGACY_INPUT, blocked in SILENT
--   LEGACY_RELEASE : releasing a key RAVYN itself is holding · always allowed (safety)
--   LOOT/UI/...    : declared non-combat callers · allowed
--   UNSCOPED       : someone bypassed the bus · always blocked
local A={total=0,nonBus=0,blocked=0,byScope={},events={},scopes=setmetatable({},{__mode="k"})}
RAVYN.InputAudit=A
local NONCOMBAT={LOOT=true,UI=true,DIALOGUE=true,CROW=true,DUNGEON=true,ANTI_AFK=true}
local function coKey() return coroutine.running() or "main" end
function A.scope() return A.scopes[coKey()] or "UNSCOPED" end
function A.withScope(scope,fn,...)
    local k=coKey(); local prev=A.scopes[k]; A.scopes[k]=scope
    local r=table.pack(pcall(fn,...))
    A.scopes[k]=prev
    if not r[1] then return false,"INPUT_ERROR:"..tostring(r[2]) end
    return table.unpack(r,2,r.n)
end
local function pushEvent(ev) table.insert(A.events,ev); while #A.events>16 do table.remove(A.events,1) end end
function A.physical(kind,detail)
    local scope=A.scope(); local allowed,why=true,nil
    if scope=="LEGACY_COMBAT" then
        if B.mode()=="SILENT" then allowed,why=false,"SILENT_MODE" end
    elseif scope=="LEGACY_RELEASE" then
        -- release of a key RAVYN holds
    elseif not NONCOMBAT[scope] then allowed,why=false,"BYPASS_NOT_VIA_COMBAT_BUS" end
    local combat=(scope=="LEGACY_COMBAT" or scope=="LEGACY_RELEASE" or scope=="UNSCOPED")
    pushEvent({at=os.clock(),kind=tostring(kind),detail=tostring(detail or ""),scope=scope,allowed=allowed,why=why})
    local f=B.fight
    if allowed then
        A.total=A.total+1; A.byScope[scope]=(A.byScope[scope] or 0)+1
        if not combat then A.nonBus=A.nonBus+1 end
        if f then if combat then f.physicalCombat=f.physicalCombat+1 else f.physicalOther=f.physicalOther+1 end end
    else
        A.blocked=A.blocked+1; A.lastBlocked={kind=kind,detail=tostring(detail or ""),scope=scope,why=why,at=os.clock()}
        if f then f.blocked=f.blocked+1 end
        if os.clock()-(A.lastBlockLog or -math.huge)>1 then
            A.lastBlockLog=os.clock()
            RAVYN.Logger:log("WARN","INPUT_BLOCKED · "..tostring(kind).." "..tostring(detail).." · "..scope.." · "..tostring(why),{})
        end
    end
    return allowed,why
end
-- menu / dialogue / loot input that does not go through a gated primitive (never combat)
function A.note(kind,detail,scope)
    scope=NONCOMBAT[scope] and scope or "UI"
    pushEvent({at=os.clock(),kind=tostring(kind),detail=tostring(detail or ""),scope=scope,allowed=true})
    A.total=A.total+1; A.nonBus=A.nonBus+1; A.byScope[scope]=(A.byScope[scope] or 0)+1
    local f=B.fight; if f then f.physicalOther=f.physicalOther+1 end
end

-- ================= LegacyCombatAdapter: the ONLY combat user of pressMouse1/2 · pressKey · setKeyState · VIM dodge =================
local LEGACY={count=0,releases=0,byKind={},last=nil}
local function legacyScoped(kind,detail,scope,fn)
    LEGACY.count=LEGACY.count+1; LEGACY.byKind[kind]=(LEGACY.byKind[kind] or 0)+1; LEGACY.last={kind=kind,detail=tostring(detail),at=os.clock()}
    return A.withScope(scope,fn)
end
function LEGACY.dispatch(a)
    if B.mode()=="SILENT" then return false,"LEGACY_BLOCKED_IN_SILENT" end
    if a.cap=="ATTACK" then
        if type(rawMouse)~="function" then return false,"LEGACY_MOUSE_UNAVAILABLE" end
        return legacyScoped(a.heavy and "M2" or "M1",a.kind,"LEGACY_COMBAT",function() return rawMouse(a.heavy and 1 or 0) end)
    elseif a.cap=="SKILL" then
        if type(rawPressKey)~="function" then return false,"LEGACY_KEY_UNAVAILABLE" end
        return legacyScoped("KEY",a.skill.key,"LEGACY_COMBAT",function() return rawPressKey(a.skill.key) end)
    elseif a.cap=="GUARD" then
        if not a.guardKey or type(rawKeyState)~="function" then return false,"GUARD_KEY_UNRESOLVED" end
        return legacyScoped("GUARD",a.guardKey,"LEGACY_COMBAT",function() return rawKeyState(a.guardKey,true) end)
    elseif a.cap=="DASH" then
        if type(rawDodge)~="function" then return false,"LEGACY_DODGE_UNAVAILABLE" end
        return legacyScoped("DASH",a.direction,"LEGACY_COMBAT",function() return rawDodge(a.direction) end)
    elseif a.cap=="PARRY" then
        local key=a.guardKey; if not key or type(rawKeyState)~="function" then return false,"PARRY_KEY_UNRESOLVED" end
        return legacyScoped("PARRY",key,"LEGACY_COMBAT",function()
            local ok,src=rawKeyState(key,true); if not ok then return false,src end
            task.wait(.06); A.withScope("LEGACY_RELEASE",function() return rawKeyState(key,false) end)
            return true,"LEGACY_PARRY_TAP"
        end)
    end
    return false,"LEGACY_UNKNOWN_ACTION"
end
function LEGACY.release(key)
    if not key or type(rawKeyState)~="function" then return false,"NO_KEY" end
    LEGACY.releases=LEGACY.releases+1
    return legacyScoped("GUARD_UP",key,"LEGACY_RELEASE",function() return rawKeyState(key,false) end)
end
RAVYN.LegacyCombatAdapter={GetStatus=function()
    return {count=LEGACY.count,releases=LEGACY.releases,byKind=Util.deepCopy(LEGACY.byKind),last=LEGACY.last,
        allowedIn="HYBRID (only for an action without a verified silent binding) · LEGACY_INPUT",backend="LEGACY_INPUT",silent=false}
end}

-- ================= SilentActionAdapter + ActionResolver =================
local SA={caps={},skills={},gen=0,resolvedAt=-math.huge,reason="NOT_RESOLVED",dirty="BOOT",dirtyAt=0,sig={},api={},
    listed={cas={},bindables={},controllers={}},testing=false,test=nil,lastTest=nil,lastTriggerCheck=0}
RAVYN.SilentActionAdapter=SA
RAVYN.SilentCombatAdapter=SA -- v1.2.1 name kept as an alias for old references
local CAS_DENY={moveForwardAction=true,moveBackwardAction=true,moveLeftAction=true,moveRightAction=true,jumpAction=true}
local WORDS={PARRY={"parry","counter","deflect"},HEAVY={"heavy","m2"},GUARD={"block","guard","defend"},DASH={"dash","dodge","roll","evade"},ATTACK={"attack","punch","swing","m1"}}
local WORD_ORDER={"PARRY","HEAVY","GUARD","DASH","ATTACK"}
local function hasToken(s,w) return s==w or string.sub(s,1,#w)==w or string.find(s,"[^%a]"..w)~=nil end
local function wordCap(s)
    s=string.lower(tostring(s or "")); if s=="" then return nil end
    for _,cap in ipairs(WORD_ORDER) do for _,w in ipairs(WORDS[cap]) do if hasToken(s,w) or (#w>4 and string.find(s,w,1,true)) then return cap end end end
    return nil
end
SA.wordCap=wordCap
function SA.casList()
    local out={}
    local ok,cas=pcall(function() return game:GetService("ContextActionService") end)
    if not ok or not cas then return out,nil end
    local ok2,all=pcall(function() return cas:GetAllBoundActionInfo() end)
    if not ok2 or type(all)~="table" then return out,cas end
    local n=0
    for name,info in pairs(all) do
        n=n+1; if n>80 then break end
        name=tostring(name)
        if not CAS_DENY[name] and string.lower(string.sub(name,1,3))~="rbx" then
            local inputs={}
            local list=(type(info)=="table") and info.inputTypes or nil
            if type(list)=="table" then for _,it in ipairs(list) do local okN,nm=pcall(function() return it.Name end); if okN and nm then table.insert(inputs,tostring(nm)) end end end
            table.insert(out,{name=name,inputs=inputs})
        end
    end
    table.sort(out,function(a,b) return a.name<b.name end)
    return out,cas
end
-- number of callbacks the game connected to a signal (C-side / core connections excluded); nil = cannot inspect.
-- RAVYN never connects to the game's own buttons, so every script connection found here belongs to the game.
local function gameCallbacks(signal)
    local gc=exec("getconnections"); if not gc then return nil end
    local ok,list=pcall(gc,signal); if not ok or type(list)~="table" then return 0 end
    local n=0
    for _,c in ipairs(list) do
        local ok2,foreign=pcall(function() return c.ForeignState end)
        if ok2 and foreign~=true then n=n+1 end
    end
    return n
end
local function underSkills(node)
    local p=node.Parent; local i=0
    while p and i<10 do if p.Name=="SkillsHolder" then return true end; p=p.Parent; i=i+1 end
    return false
end
local function buttonBinding(btn,cap,rank,key,index)
    local canInspect=exec("getconnections")~=nil
    local info={}
    for _,sn in ipairs({"MouseButton1Click","Activated","MouseButton1Down","MouseButton1Up"}) do
        local ok,sig=pcall(function() return btn[sn] end)
        info[sn]=(ok and sig) and gameCallbacks(sig) or nil
    end
    local tap=nil
    if canInspect then
        if (info.MouseButton1Click or 0)>0 then tap="MouseButton1Click" elseif (info.Activated or 0)>0 then tap="Activated" elseif (info.MouseButton1Down or 0)>0 then tap="MouseButton1Down" end
        if not tap then return nil end -- the game's UI does not listen to this button
    else
        tap="MouseButton1Click"
    end
    local total=0; for _,v in pairs(info) do total=total+(v or 0) end
    local path="?"; pcall(function() path=btn:GetFullName() end)
    return {id="GUI:"..path.."@"..tap,kind="GUI",cap=cap,key=key,index=index,inst=btn,tap=tap,
        down=(canInspect and (info.MouseButton1Down or 0)>0) and "MouseButton1Down" or nil,
        up=(canInspect and (info.MouseButton1Up or 0)>0) and "MouseButton1Up" or nil,
        callbacks=canInspect and total or nil,rank=rank+(canInspect and 0 or 3),
        label="UI callback · "..tostring(btn.Name).."."..tap..(canInspect and (" · "..total.." game callback"..(total==1 and "" or "s")) or " · callbacks not inspectable")}
end
local function slotButtons(index)
    local slot=EV.slot(index); if not slot then return {} end
    local out={}
    if slot:IsA("GuiButton") then table.insert(out,slot) end
    local ok,desc=pcall(function() return slot:GetDescendants() end)
    if ok then for i,d in ipairs(desc) do if i>60 then break end; if d:IsA("GuiButton") then table.insert(out,d) end end end
    return out
end
-- bounded walk over the game's own ScreenGuis (RAVYN's GUIs excluded) · only when resolving, never per tick
local function actionButtons()
    local pg=LP and LP:FindFirstChildOfClass("PlayerGui"); if not pg then return {} end
    local out={}; local queue={}; local head=1; local visited=0
    for _,g in ipairs(pg:GetChildren()) do
        if string.sub(tostring(g.Name),1,5)~="RAVYN" and g~=RAVYN._gui then table.insert(queue,{g,0}) end
    end
    while head<=#queue and visited<2500 do
        local node,depth=queue[head][1],queue[head][2]; head=head+1; visited=visited+1
        local okB,isBtn=pcall(function() return node:IsA("GuiButton") end)
        if okB and isBtn and not underSkills(node) then
            local cap=wordCap(node.Name)
            if not cap then local okT,t=pcall(function() return node.Text end); if okT then cap=wordCap(t) end end
            if cap then table.insert(out,{btn=node,cap=cap}) end
        end
        if depth<12 then local ok,ch=pcall(function() return node:GetChildren() end); if ok then for _,c in ipairs(ch) do table.insert(queue,{c,depth+1}) end end end
    end
    return out
end
local function toolCandidate()
    local h=liveHumanoid(); local ch=h and h.Parent; if not ch then return nil end
    local ok,tool=pcall(function() return ch:FindFirstChildOfClass("Tool") end)
    if not ok or not tool then return nil end
    local okS,sig=pcall(function() return tool.Activated end)
    local n=(okS and sig) and gameCallbacks(sig) or nil
    return {id="TOOL:"..tostring(tool.Name),kind="TOOL",cap="ATTACK",inst=tool,rank=(n and n>0) and 2 or 5,callbacks=n,
        label="Tool:Activate() · "..tostring(tool.Name)..((n==nil) and " · callbacks not inspectable" or (" · "..n.." local Activated callback"..(n==1 and "" or "s")))}
end
local function listBindables()
    local out={}; local roots={}
    pcall(function() table.insert(roots,game:GetService("ReplicatedStorage")) end)
    pcall(function() local ps=LP:FindFirstChild("PlayerScripts"); if ps then table.insert(roots,ps) end end)
    pcall(function() local h=liveHumanoid(); if h and h.Parent then table.insert(roots,h.Parent) end end)
    local seen=0
    for _,r in ipairs(roots) do
        local queue={{r,0}}; local head=1
        while head<=#queue and seen<1500 and #out<12 do
            local node,depth=queue[head][1],queue[head][2]; head=head+1; seen=seen+1
            local okB,isB=pcall(function() return node:IsA("BindableEvent") or node:IsA("BindableFunction") end)
            if okB and isB and (wordCap(node.Name) or string.find(string.lower(tostring(node.Name)),"skill",1,true)) then
                local p="?"; pcall(function() p=node:GetFullName() end); table.insert(out,p)
            end
            if depth<5 and node.Name~="Player_Service" then local ok,ch=pcall(function() return node:GetChildren() end); if ok then for _,c in ipairs(ch) do table.insert(queue,{c,depth+1}) end end end
        end
    end
    return out
end
local function listControllers()
    local out={}; local envs={}
    local gr=exec("getrenv")
    if gr then
        local ok,e=pcall(gr)
        if ok and type(e)=="table" then
            local okG,g=pcall(function() return rawget(e,"_G") end); if okG and type(g)=="table" then table.insert(envs,{"_G",g}) end
            local okS,s=pcall(function() return rawget(e,"shared") end); if okS and type(s)=="table" then table.insert(envs,{"shared",s}) end
        end
    end
    for _,pair in ipairs(envs) do
        pcall(function()
            local n=0
            for k,v in next,pair[2] do
                n=n+1; if n>200 or #out>=10 then break end
                if type(v)=="function" and wordCap(k) then table.insert(out,pair[1].."."..tostring(k).."()")
                elseif type(v)=="table" then
                    local m=0
                    for k2,v2 in next,v do
                        m=m+1; if m>80 or #out>=10 then break end
                        if type(v2)=="function" and (wordCap(k2) or string.find(string.lower(tostring(k2)),"skill",1,true)) then table.insert(out,pair[1].."."..tostring(k).."."..tostring(k2).."()") end
                    end
                end
            end
        end)
    end
    return out
end
local function capState(cap) return {cap=cap,status="UNAVAILABLE",binding=nil,candidates={},reason="NO_LOCAL_ACTION_FOUND"} end
local function addCand(st,b) if st and b then table.insert(st.candidates,b) end end
local function currentSig()
    local h=liveHumanoid(); local ch=h and h.Parent; local tool=nil
    if ch then local ok,t=pcall(function() return ch:FindFirstChildOfClass("Tool") end); tool=ok and t or nil end
    local AI=RAVYN.AdaptiveIntel; local M=RAVYN.CombatMobility
    local keys={}; for _,k in ipairs((M and M.skillKeys) or {}) do table.insert(keys,tostring(k.index)..":"..tostring(k.key)) end
    return {char=(LP and LP.Character) or ch,tool=tool,loadout=AI and AI.loadoutGeneration or 0,skills=table.concat(keys,",")}
end
function SA.bindingFor(capKey)
    if type(capKey)~="string" then return nil end
    if string.sub(capKey,1,6)=="SKILL:" then return SA.skills[string.sub(capKey,7)] end
    return SA.caps[capKey]
end
function SA.capStatus(cap)
    if cap=="SKILL" then
        local n,v,p=0,0,0
        for _,st in pairs(SA.skills) do n=n+1; if st.status=="VERIFIED_SILENT" then v=v+1 elseif st.status=="PARTIAL" then p=p+1 end end
        if n==0 then return "UNAVAILABLE","no hotbar skills read" end
        if v==n then return "VERIFIED_SILENT",v.."/"..n.." skills verified" end
        if v>0 or p>0 then return "PARTIAL",v.."/"..n.." verified · "..p.." candidate"..(p==1 and "" or "s") end
        return "UNAVAILABLE","0/"..n.." skills have a local action"
    end
    local st=SA.caps[cap]; if not st then return "UNAVAILABLE","not resolved yet" end
    return st.status,st.reason
end
function SA.summary()
    local parts={}
    for _,c in ipairs({"ATTACK","SKILL","GUARD","DASH","PARRY"}) do local s=SA.capStatus(c); table.insert(parts,c.." "..s) end
    return table.concat(parts," · ")
end
function SA.resolve(reason)
    local now=os.clock()
    SA.gen=SA.gen+1; SA.resolvedAt=now; SA.reason=tostring(reason or "MANUAL"); SA.dirty=nil
    SA.api={getconnections=exec("getconnections")~=nil,firesignal=exec("firesignal")~=nil,cas=false,getrenv=exec("getrenv")~=nil}
    local caps={ATTACK=capState("ATTACK"),HEAVY=capState("HEAVY"),GUARD=capState("GUARD"),DASH=capState("DASH"),PARRY=capState("PARRY")}
    local skills={}
    local okK,keys=pcall(currentSkillKeys); keys=(okK and keys) or {}
    for _,k in ipairs(keys) do skills[k.key]={cap="SKILL",key=k.key,index=k.index,status="UNAVAILABLE",binding=nil,candidates={},reason="NO_LOCAL_ACTION_FOUND"} end
    -- hotbar / guard / dodge keys are IDENTIFIERS here: they name which game action to look for
    local guardKey=nil; pcall(function() guardKey=(resolveGuardKey(now)) end)
    local dodgeKey="Q"; pcall(function() dodgeKey=string.upper(tostring(evoCfg().Defense.DodgeKey or "Q")) end)
    -- 1) ContextActionService actions the game bound itself
    local acts,cas=SA.casList(); SA.api.cas=cas~=nil; SA.listed.cas={}
    for _,a in ipairs(acts) do
        local inputs=table.concat(a.inputs,",")
        table.insert(SA.listed.cas,a.name.." ["..inputs.."]")
        local function mk(cap,rank,key) return {id="CAS:"..a.name,kind="CAS",cap=cap,key=key,name=a.name,cas=cas,rank=rank,label="CAS action · "..a.name.." ["..inputs.."]"} end
        local function has(nm) for _,x in ipairs(a.inputs) do if x==nm then return true end end; return false end
        local matched=false
        for key,st in pairs(skills) do if has(key) then local b=mk("SKILL",1,key); b.index=st.index; addCand(st,b); matched=true end end
        if has("MouseButton1") then addCand(caps.ATTACK,mk("ATTACK",1)); matched=true end
        if has("MouseButton2") then addCand(caps.HEAVY,mk("HEAVY",1)); matched=true end
        if guardKey and has(guardKey) and not skills[guardKey] then addCand(caps.GUARD,mk("GUARD",1)); matched=true end
        if dodgeKey and has(dodgeKey) and not skills[dodgeKey] then addCand(caps.DASH,mk("DASH",1)); matched=true end
        if not matched then local cap=wordCap(a.name); if cap then addCand(caps[cap],mk(cap,4)) end end
    end
    -- 2) callbacks the game's own UI connected to its buttons (hotbar slots + action buttons)
    if SA.api.firesignal or SA.api.getconnections then
        for key,st in pairs(skills) do for _,btn in ipairs(slotButtons(st.index)) do addCand(st,buttonBinding(btn,"SKILL",2,key,st.index)) end end
        for _,x in ipairs(actionButtons()) do addCand(caps[x.cap],buttonBinding(x.btn,x.cap,3)) end
    end
    -- 3) Tool activation API
    addCand(caps.ATTACK,toolCandidate())
    -- listed only (never invoked)
    SA.listed.bindables=listBindables(); SA.listed.controllers=listControllers()
    local ver=scfg().Verified or {}
    local function choose(st,capKey)
        table.sort(st.candidates,function(x,y) return x.rank<y.rank end)
        while #st.candidates>6 do table.remove(st.candidates) end
        local pv=ver[capKey]
        if type(pv)=="table" then
            for _,b in ipairs(st.candidates) do if pv.id==b.id then b.verified=true; b.restored=true; b.lastEvidence=pv.evidence; st.binding=b; break end end
        end
        st.binding=st.binding or st.candidates[1]
        if st.binding and st.binding.verified then st.status="VERIFIED_SILENT"; st.reason="verified earlier ("..tostring(st.binding.lastEvidence)..") · re-confirmed on use"
        elseif st.binding then st.status="PARTIAL"; st.reason="local action found · not verified yet"
        else st.status="UNAVAILABLE"; st.reason=(SA.api.cas or SA.api.getconnections or SA.api.firesignal) and "no local game action found" or "executor exposes no inspection API" end
    end
    for cap,st in pairs(caps) do choose(st,cap) end
    for key,st in pairs(skills) do choose(st,"SKILL:"..key) end
    SA.caps=caps; SA.skills=skills; SA.sig=currentSig()
    RAVYN.Logger:log("INFO","SILENT_RESOLVE · "..SA.reason.." · "..SA.summary(),{})
    if not SA.toldUser and B.mode()=="SILENT" and caps.ATTACK.status~="VERIFIED_SILENT" and D and D.event then
        SA.toldUser=true
        D.event("Combat input is SILENT: attack "..caps.ATTACK.status.." · nothing is sent until a local action is verified (Combat → Input engine → Verify) · or choose Hybrid","warn")
    end
    return result(true,"SILENT_RESOLVED",SA.summary())
end
-- invoke a silent binding. phase: TAP | DOWN | UP. Never loops, never retries, never touches input simulation.
local function fireSignal(b,sn,args)
    local okS,sig=pcall(function() return b.inst[sn] end); if not okS or not sig then return false,"SIGNAL_MISSING" end
    local fs=exec("firesignal")
    if fs then local ok,err=pcall(fs,sig,table.unpack(args)); return ok,ok and ("firesignal "..sn) or ("FIRESIGNAL_ERROR:"..tostring(err)) end
    local gc=exec("getconnections"); if not gc then return false,"NO_FIRESIGNAL" end
    local okL,list=pcall(gc,sig); if not okL or type(list)~="table" then return false,"GETCONNECTIONS_FAILED" end
    local fired=0
    for _,c in ipairs(list) do
        pcall(function()
            local fn,foreign=c.Function,c.ForeignState
            if foreign==true or type(fn)~="function" then return end
            if type(c.Fire)=="function" then c:Fire(table.unpack(args)) else task.spawn(fn,table.unpack(args)) end
            fired=fired+1
        end)
    end
    return fired>0,fired>0 and ("connection:Fire "..sn.." ×"..fired) or "NO_GAME_CALLBACK_FIRED"
end
local function silentInvoke(b,phase)
    phase=phase or "TAP"
    if not b then return false,"NO_BINDING" end
    if b.kind=="CAS" then
        local cas=b.cas; if not cas then return false,"CAS_UNAVAILABLE" end
        local function call(state) return pcall(function() return cas:CallFunction(b.name,state,nil) end) end
        if phase=="UP" then local ok,err=call(Enum.UserInputState.End); return ok,ok and "CAS:CallFunction End" or ("CAS_ERROR:"..tostring(err)) end
        local ok,err=call(Enum.UserInputState.Begin)
        if not ok then return false,"CAS_ERROR:"..tostring(err) end
        if phase=="TAP" then task.delay(.05,function() pcall(function() cas:CallFunction(b.name,Enum.UserInputState.End,nil) end) end) end
        return true,"CAS:CallFunction "..(phase=="TAP" and "Begin/End" or "Begin")
    elseif b.kind=="GUI" then
        if not (b.inst and b.inst.Parent) then return false,"UI_BUTTON_GONE" end
        local sn=(phase=="DOWN" and b.down) or (phase=="UP" and b.up) or b.tap
        if not sn then return false,"NO_"..phase.."_SIGNAL" end
        local args={}
        if sn=="MouseButton1Down" or sn=="MouseButton1Up" then
            local okP,p,s=pcall(function() return b.inst.AbsolutePosition,b.inst.AbsoluteSize end)
            if okP and p and s then args={math.floor(p.X+s.X/2),math.floor(p.Y+s.Y/2)} end
        end
        local ok,src=fireSignal(b,sn,args)
        if ok and phase=="TAP" and sn=="MouseButton1Down" and b.up then task.delay(.05,function() pcall(fireSignal,b,b.up,args) end) end
        return ok,src
    elseif b.kind=="TOOL" then
        if not (b.inst and b.inst.Parent) then return false,"TOOL_GONE" end
        local ok,err=pcall(function() b.inst:Activate() end)
        return ok,ok and "Tool:Activate()" or ("TOOL_ERROR:"..tostring(err))
    end
    return false,"UNKNOWN_BINDING"
end
local function persistVerified(capKey,b,evidence)
    local v=Util.deepCopy(scfg().Verified or {})
    if b then v[capKey]={id=b.id,at=os.time(),evidence=tostring(evidence or "")} else v[capKey]=nil end
    pcall(function() RAVYN:SetConfig("SilentCombat.Verified",v) end)
end
local function markVerified(capKey,st,b,evidence)
    b.verified=true; b.restored=false; b.noEvidence=0; b.lastEvidence=evidence
    st.binding=b; st.status="VERIFIED_SILENT"; st.reason="verified · "..tostring(evidence)
    persistVerified(capKey,b,evidence)
    RAVYN.Logger:log("INFO","SILENT_VERIFIED · "..capKey.." · "..b.label.." · "..tostring(evidence),{})
end
-- in-combat bookkeeping: a VERIFIED binding that keeps producing no local evidence is demoted, never kept silently
local function bindingOutcome(a,confirmed,evidence)
    local st=SA.bindingFor(a.capKey); local b=a.bindingRef
    if not (st and b and st.binding==b) then return end
    if confirmed then b.noEvidence=0; b.restored=false; b.lastEvidence=evidence; return end
    b.noEvidence=(b.noEvidence or 0)+1
    local limit=b.restored and 3 or (tonumber(scfg().DemoteAfterNoEvidence) or 4)
    if b.verified and b.noEvidence>=limit then
        b.verified=false; st.status="PARTIAL"; st.reason="demoted · no local evidence in "..b.noEvidence.." uses"
        persistVerified(a.capKey,nil)
        RAVYN.Logger:log("WARN","SILENT_DEMOTED · "..a.capKey.." · "..b.label,{})
    end
end
local REQUIRED={ATTACK=2,HEAVY=1,SKILL=1,GUARD=1,DASH=1,PARRY=1}
-- when one game action is the candidate for several capabilities (e.g. one CAS "Combat" action bound to M1 and Z),
-- a generic animation cannot tell them apart: only capability-specific evidence may verify it then
local SPECIFIC={SKILL={SLOT_COOLDOWN=true},GUARD={STATE_ATTR=true},PARRY={STATE_ATTR=true},DASH={DISPLACEMENT=true}}
local function sharedBinding(capKey,b)
    for k,st in pairs(SA.caps) do if k~=capKey then for _,c in ipairs(st.candidates) do if c.id==b.id then return true end end end end
    for key,st in pairs(SA.skills) do if ("SKILL:"..key)~=capKey then for _,c in ipairs(st.candidates) do if c.id==b.id then return true end end end end
    return false
end
local WINDOW={ATTACK=.45,HEAVY=.6,SKILL=1.0,GUARD=.4,DASH=.6,PARRY=.45}
local function capOf(capKey) return (string.sub(capKey,1,6)=="SKILL:") and "SKILL" or capKey end
-- explicit verification: invokes ONE candidate silently, waits for local evidence. Physical input during the test = invalid.
local function verifyBinding(capKey,b)
    local cap=capOf(capKey); local need=REQUIRED[cap] or 1
    if cap=="GUARD" and b.kind=="GUI" and not (b.down and b.up) then b.lastError="NO_HOLD_SIGNAL"; return false,nil,0 end
    local skill=b.index and {index=b.index,key=b.key} or nil
    local specific=sharedBinding(capKey,b) and SPECIFIC[cap] or nil
    local got,attempts,lastEv=0,0,nil
    while got<need and attempts<need+2 and SA.testing and not RAVYN._destroyed do
        attempts=attempts+1
        local me=liveHumanoid(); local myHp=me and tonumber(me.Health) or nil
        local physBefore=A.total
        local snap=EV.snap((cap=="HEAVY") and "ATTACK" or cap,LiveAction.target,skill)
        local ok,src=silentInvoke(b,(cap=="GUARD") and "DOWN" or "TAP")
        B.testExecs=B.testExecs+1
        if not ok then b.lastError=src; break end
        local ev=nil; local deadline=os.clock()+(WINDOW[cap] or .5)
        repeat
            task.wait(.05)
            local e=EV.evaluate(snap)
            if EV.localOnly(e) then
                if not specific then ev=e else for k in pairs(specific) do if e[k]~=nil then ev=e end end end
            end
        until ev or os.clock()>=deadline or not SA.testing
        if cap=="GUARD" then silentInvoke(b,"UP") end
        -- any other input (loot key, menu click) or a hit on you during the window makes this attempt inconclusive:
        -- it is neither counted as evidence nor as a failure
        local me2=liveHumanoid(); local hitMe=myHp and me2 and tonumber(me2.Health) and me2.Health<myHp-0.01
        if A.total~=physBefore then b.lastError="INCONCLUSIVE · other input during the test window"
        elseif hitMe then b.lastError="INCONCLUSIVE · you were hit during the test window"
        elseif ev then got=got+1; lastEv=EV.text(ev); b.lastError=nil
        else b.lastError=specific and "NO_SPECIFIC_EVIDENCE (shared game action)" or "NO_LOCAL_EVIDENCE" end
        task.wait((cap=="SKILL") and .2 or .45)
    end
    return got>=need,lastEv,attempts
end
function SA.verifyAll(only)
    if SA.testing then return result(false,"SILENT_VERIFY_RUNNING") end
    B.releaseAll("SILENT_VERIFY")
    SA.testing=true; SA.test={startedAt=os.clock(),step="RESOLVING",results={}}
    task.spawn(function()
        local ok,err=pcall(function()
            SA.resolve("VERIFY")
            local order={"ATTACK"}
            local sk={}; for key,st in pairs(SA.skills) do table.insert(sk,{key=key,index=st.index or 99}) end
            table.sort(sk,function(x,y) return x.index<y.index end)
            for _,x in ipairs(sk) do table.insert(order,"SKILL:"..x.key) end
            for _,c in ipairs({"GUARD","DASH","PARRY","HEAVY"}) do table.insert(order,c) end
            for _,capKey in ipairs(order) do
                if not SA.testing or RAVYN._destroyed then break end
                if not only or only==capKey then
                    local st=SA.bindingFor(capKey)
                    if st and #st.candidates>0 then
                        local passed=false
                        for i,b in ipairs(st.candidates) do
                            if i>(tonumber(scfg().MaxCandidates) or 3) or not SA.testing then break end
                            SA.test.step=capKey.." · "..b.label
                            local pass,ev,att=verifyBinding(capKey,b)
                            table.insert(SA.test.results,{cap=capKey,label=b.label,pass=pass,evidence=ev,attempts=att,error=b.lastError})
                            if pass then markVerified(capKey,st,b,ev); passed=true; break end
                        end
                        if not passed then
                            if st.binding then st.binding.verified=false end
                            st.status="PARTIAL"; st.reason="not verified · no local evidence from "..math.min(#st.candidates,tonumber(scfg().MaxCandidates) or 3).." candidate(s)"
                            persistVerified(capKey,nil)
                        end
                    else
                        table.insert(SA.test.results,{cap=capKey,label="—",pass=false,error="UNAVAILABLE · no local game action found"})
                    end
                end
            end
        end)
        SA.test.finishedAt=os.clock(); SA.test.step=ok and "DONE" or ("ERROR · "..tostring(err))
        SA.lastTest=SA.test; SA.testing=false
        RAVYN.Logger:log(ok and "INFO" or "ERROR","SILENT_VERIFY · "..SA.summary(),{error=(not ok) and tostring(err) or nil})
    end)
    return result(true,"SILENT_VERIFY_STARTED")
end
function SA.clearVerified()
    pcall(function() RAVYN:SetConfig("SilentCombat.Verified",{}) end)
    for _,st in pairs(SA.caps) do if st.binding then st.binding.verified=false; st.status="PARTIAL"; st.reason="verification cleared" end end
    for _,st in pairs(SA.skills) do if st.binding then st.binding.verified=false; st.status="PARTIAL"; st.reason="verification cleared" end end
    return result(true,"SILENT_VERIFICATION_CLEARED")
end
function SA.GetStatus()
    local caps={}
    for _,c in ipairs({"ATTACK","SKILL","GUARD","DASH","PARRY"}) do local s,why=SA.capStatus(c); local st=SA.caps[c]; caps[c]={status=s,reason=why,binding=st and st.binding and st.binding.label or nil} end
    local anyVerified=false; for _,c in pairs(caps) do if c.status=="VERIFIED_SILENT" then anyVerified=true end end
    return {silent=anyVerified,backend="SILENT_LOCAL",status=caps.ATTACK.status,caps=caps,reason=SA.reason,gen=SA.gen,api=SA.api,testing=SA.testing}
end

-- ================= CombatActionBus =================
local stunAt,stunVal=-math.huge,false
function B.playerStunned()
    local now=os.clock(); if now-stunAt<.1 then return stunVal end; stunAt=now; stunVal=false
    local h=liveHumanoid(); if not h then stunVal=true; return true end
    local ok,hp=pcall(function() return h.Health end); if ok and tonumber(hp) and hp<=0 then stunVal=true; return true end
    local ok2,st=pcall(function() return h:GetState() end)
    if ok2 and (st==Enum.HumanoidStateType.Dead or st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown) then stunVal=true; return true end
    local ch=h.Parent
    if ch then
        for _,n in ipairs({"Stun","Stunned","Ragdoll","Ragdolled","Knocked"}) do
            local okV,v=pcall(function() return ch:FindFirstChild(n) end)
            if okV and v then
                local on=true
                pcall(function() if v:IsA("BoolValue") then on=v.Value==true elseif v:IsA("NumberValue") or v:IsA("IntValue") then on=(tonumber(v.Value) or 0)>0 end end)
                if on then stunVal=true; return true end
            end
            local okA,a=pcall(function() return ch:GetAttribute(n) end)
            if okA and (a==true or (type(a)=="number" and a>0)) then stunVal=true; return true end
        end
    end
    return false
end
local function fightFor(target,now)
    if not (target and target.id) then return B.fight end
    local f=B.fight
    if not f or f.id~=target.id then
        if f then f.endedAt=now; B.lastFight=f end
        f={id=target.id,name=target.name,boss=target.isBoss==true or target.classification=="BOSS",startedAt=now,mode=B.mode(),
            requests=0,executed=0,silent=0,legacy=0,physicalCombat=0,physicalOther=0,blocked=0,rejects={}}
        B.fight=f
    end
    f.lastAt=now; f.goneAt=nil
    return f
end
-- rejections that describe a capability (not a transient lock/cooldown)
local CAP_CODES={SILENT_UNAVAILABLE=true,THRESHOLD_FINISHER_SILENT_UNAVAILABLE=true,LEGACY_BLOCKED_IN_SILENT=true,GUARD_KEY_UNRESOLVED=true,
    PARRY_KEY_UNRESOLVED=true,ACTION_FAILED=true,PLAYER_STUNNED=true,SILENT_VERIFY_RUNNING=true}
B.CAP_CODES=CAP_CODES
local function reject(code,kind,f,detail)
    B.lastReject={code=code,kind=kind,at=os.clock(),detail=detail}
    if CAP_CODES[code] then B.lastCapReject=B.lastReject end
    B.rejects[code]=(B.rejects[code] or 0)+1
    if f then f.rejects[code]=(f.rejects[code] or 0)+1 end
    return result(false,code,{kind=kind,detail=detail,mode=B.mode()})
end
function B.backendFor(capKey,finisher)
    local mode=B.mode()
    if mode=="LEGACY_INPUT" then return "LEGACY_INPUT",nil end
    local st=SA.bindingFor(capKey)
    if st and st.status=="VERIFIED_SILENT" and st.binding then return "SILENT_LOCAL",st.binding end
    if mode=="HYBRID" then return "LEGACY_INPUT",nil end
    return nil,nil,finisher and "THRESHOLD_FINISHER_SILENT_UNAVAILABLE" or "SILENT_UNAVAILABLE"
end
local LOCK={ATTACK=.35,HEAVY=.6,SKILL=.9,FINISHER=.6,GUARD=.2,DASH=.45,PARRY=.35}
local function lockWindow(a)
    if a.kind=="ATTACK" then
        local M=RAVYN.CombatMobility; local pp=(M and M.params and M.params()) or {m1=.14}
        return math.max(.08,math.min(LOCK.ATTACK,tonumber(pp.m1) or .14))
    end
    if a.kind=="SKILL" then local c=RAVYN.Config.CombatMobility; return math.max(.3,math.min(LOCK.SKILL,tonumber(c and c.SkillCastLock) or .45)) end
    return LOCK[a.kind] or .3
end
-- damage learning: target HP fraction between consecutive offensive dispatches (samples at death are skipped)
local function closeDamage(now,target)
    local p=B.pendingDmg; if not p then return end
    B.pendingDmg=nil
    if target and target.id~=p.targetId then return end
    local f=EV.hpFrac(p.hum)
    if f and f>0 and f<=p.frac and now-p.at<=1.2 then
        local drop=p.frac-f
        local s=B.dmg[p.key] or {ema=0,n=0,max=0}
        s.ema=(s.n==0) and drop or (s.ema*.7+drop*.3); s.n=s.n+1; s.max=math.max(s.max,drop); s.last=drop
        B.dmg[p.key]=s
    end
end
local function noteDispatch(a,target,now)
    local h=a.snap and a.snap.hum or EV.targetHum(target)
    local f=a.hpFracBefore
    if f and f>0 and target then B.pendingDmg={key=a.dmgKey,targetId=target.id,frac=f,at=now,hum=h} end
end
function B.predictKey(k)
    local s=B.dmg[k]
    if s and s.n>=2 then return s.ema,s end
    local key=string.match(tostring(k),"^SKILL:(.+)$")
    if key then local E=RAVYN.CombatEvolution; local st=E and E.skillStats and E.skillStats[key]; if st and (st.samples or 0)>=2 and (st.avgDamage or 0)>0 then return st.avgDamage/100,st end end
    return nil
end
function B.predict(kind,key) return B.predictKey((kind=="SKILL" and key) and ("SKILL:"..key) or kind) end
-- the largest damage this action has actually dealt (fraction of max HP)
function B.predictMax(kind,key)
    local k=(kind=="SKILL" and key) and ("SKILL:"..key) or kind
    local s=B.dmg[k]; if s and s.n>=2 then return s.max end
    if kind=="SKILL" and key then local E=RAVYN.CombatEvolution; local st=E and E.skillStats and E.skillStats[key]; if st and (st.samples or 0)>=2 and (st.best or 0)>0 then return st.best/100 end end
    return nil
end
-- predicted damage of an offensive action that was dispatched but has not landed yet
function B.inflight(target,now)
    local p=B.pendingDmg
    if not (p and target and p.targetId==target.id) or now-p.at>.35 then return 0 end
    local f=EV.hpFrac(p.hum); if f and f<p.frac-1e-4 then return 0 end
    return (B.predictKey(p.key)) or 0
end
local function settle(c,a,now,evidence)
    a.doneAt=now; a.evidence=evidence; a.confirmed=evidence~=nil
    c.current=nil; c.last=a
    c.state=a.confirmed and "CONFIRMED" or "UNCONFIRMED"
    c.readyAt=math.max(now,(a.execAt or now)+(a.minGap or 0))
    if a.backend=="SILENT_LOCAL" then pcall(bindingOutcome,a,a.confirmed,evidence) end
    B.lastAction=a
end
local function stepChannel(c,now)
    if c.state=="ACTION_LOCK" and c.current then
        local a=c.current
        if now>=(a.nextPoll or 0) then
            a.nextPoll=now+.05
            local ok,ev=pcall(EV.evaluate,a.snap)
            if ok and EV.first(ev) then settle(c,a,now,EV.text(ev)); return end
        end
        if now>=c.lockUntil then settle(c,a,now,nil) end
    elseif c.state=="CONFIRMED" or c.state=="UNCONFIRMED" or c.state=="COOLDOWN" then
        c.state=(now>=c.readyAt) and "READY" or "COOLDOWN"
    end
end
function B.step(now)
    now=now or os.clock()
    stepChannel(CH.OFFENSE,now); stepChannel(CH.DEFENSE,now)
    local p=B.pendingDmg; if p and now-p.at>.9 then closeDamage(now,nil) end
end
local function newAction(kind,target,opts,now)
    B.seq=B.seq+1
    return {seq=B.seq,kind=kind,target=target and target.name,targetId=target and target.id,targetRef=target,at=now,source=opts.source or "?",finisher=opts.finisher==true}
end
local function actionLabel(a)
    if a.cap=="SKILL" then return (a.finisher and "FINISHER " or "").."SKILL "..tostring(a.skill and a.skill.key) end
    if a.cap=="ATTACK" then return (a.finisher and "FINISHER " or "")..(a.heavy and "HEAVY" or "M1") end
    if a.cap=="GUARD" then return "GUARD "..(a.enabled and "HOLD" or "RELEASE") end
    return a.cap or a.kind
end
-- REQUESTED → EXECUTING → ACTION_LOCK (→ CONFIRMED/UNCONFIRMED → COOLDOWN → READY in B.step)
local function submit(a,chan,now)
    local c=CH[chan]
    c.state="REQUESTED"; a.chan=chan; a.label=actionLabel(a)
    local backend,binding,why=B.backendFor(a.capKey,a.finisher)
    if not backend then c.state=(now>=c.readyAt) and "READY" or "COOLDOWN"; return reject(why,a.kind,B.fight,a.capKey) end
    c.state="EXECUTING"; a.backend=backend; a.bindingRef=binding
    a.displayLabel=(backend=="LEGACY_INPUT") and (a.finisher and "THRESHOLD_FINISHER_LEGACY_INPUT" or "LEGACY") or (a.finisher and "THRESHOLD_FINISHER_SILENT" or "SILENT")
    a.snap=EV.snap(a.cap,a.targetRef,a.skill)
    -- damage learning: close the previous action's window at THIS action's pre-dispatch HP
    if a.dmgKey and a.targetRef then closeDamage(now,a.targetRef); a.hpFracBefore=EV.hpFrac(a.snap.hum) end
    local ok,src
    if backend=="SILENT_LOCAL" then ok,src=silentInvoke(binding,a.phase) else ok,src=LEGACY.dispatch(a) end
    a.ok=ok; a.src=src; a.execAt=os.clock()
    if not ok then
        c.state="READY"; a.failed=true; B.lastAction=a
        -- a silent binding whose button / tool / CAS action disappeared: re-resolve instead of retrying it
        if backend=="SILENT_LOCAL" and (src=="UI_BUTTON_GONE" or src=="TOOL_GONE" or string.find(tostring(src),"^CAS_ERROR")) then SA.dirty="BINDING_GONE"; SA.dirtyAt=now end
        return reject("ACTION_FAILED",a.kind,B.fight,tostring(src))
    end
    B.execCount=B.execCount+1
    if backend=="SILENT_LOCAL" then B.silentCount=B.silentCount+1 else B.legacyCount=B.legacyCount+1 end
    if a.finisher then B.finisherCount=B.finisherCount+1 end
    local f=B.fight; if f then f.executed=f.executed+1; if backend=="SILENT_LOCAL" then f.silent=f.silent+1 else f.legacy=f.legacy+1 end end
    table.insert(B.history,{seq=a.seq,label=a.label,backend=backend,at=a.execAt}); while #B.history>12 do table.remove(B.history,1) end
    c.state="ACTION_LOCK"; c.current=a; c.lockUntil=now+lockWindow(a); a.nextPoll=now+.03
    B.lastAction=a
    return result(true,(backend=="SILENT_LOCAL") and "EXECUTED_SILENT" or "EXECUTED_LEGACY",
        {seq=a.seq,backend=backend,binding=binding and binding.label or nil,src=src,label=a.displayLabel,action=a.label})
end
local function offenseGate(kind,target,now,opts)
    if RAVYN._destroyed then return "BUS_DESTROYED" end
    if SA.testing then return "SILENT_VERIFY_RUNNING" end
    if not opts.manual and not (RAVYN.FSM and RAVYN.FSM.state=="RUNNING") then return "NOT_RUNNING" end
    local IK=RAVYN.InstaKillAdapter
    if not opts.finisher and IK and IK.locked then return "FINISHER_LOCK" end
    if not target then return "NO_TARGET" end
    if target.alive==false then return "TARGET_DEAD" end
    local hf=EV.hpFrac(EV.targetHum(target)); if hf and hf<=0 then return "TARGET_DEAD" end
    local root=liveRoot(); local tp=targetBasis(target)
    if not (root and tp) then return "NO_POSITION" end
    local d=(root.Position-tp).Magnitude
    local p=(Hooks.activeProfile and Hooks.activeProfile()) or {}
    local range=opts.range or ((kind=="SKILL") and math.max((p.attackDistance or 9)+10,18) or math.max((p.attackDistance or 9)+1.5,12))
    if d>range then return "OUT_OF_RANGE" end
    if B.playerStunned() then return "PLAYER_STUNNED" end
    if not opts.finisher then
        if B.guardDown then return "GUARD_HELD" end
        if now<B.defenseUntil then return "DEFENSE_ACTIVE" end
    end
    local c=CH.OFFENSE
    if c.state=="REQUESTED" or c.state=="EXECUTING" then return "PREVIOUS_ACTION_RUNNING" end
    if c.state=="ACTION_LOCK" then return "ACTION_LOCK" end
    return nil
end
local function defenseGate(now,opts)
    if RAVYN._destroyed then return "BUS_DESTROYED" end
    if SA.testing then return "SILENT_VERIFY_RUNNING" end
    if not opts.manual and not (RAVYN.FSM and RAVYN.FSM.state=="RUNNING") then return "NOT_RUNNING" end
    local IK=RAVYN.InstaKillAdapter; if IK and IK.locked then return "FINISHER_LOCK" end
    if B.playerStunned() then return "PLAYER_STUNNED" end
    local c=CH.DEFENSE
    if c.state=="REQUESTED" or c.state=="EXECUTING" then return "PREVIOUS_ACTION_RUNNING" end
    if c.state=="ACTION_LOCK" then return "ACTION_LOCK" end
    return nil
end
local function findSkill(key)
    key=string.upper(tostring(key or ""))
    local ok,keys=pcall(currentSkillKeys)
    for _,k in ipairs((ok and keys) or {}) do if k.key==key then return k end end
    return nil
end

function B:RequestAttack(target,opts)
    opts=opts or {}; local now=os.clock(); B.step(now)
    target=target or LiveAction.target
    local f=fightFor(target,now); if f then f.requests=f.requests+1 end
    local heavy=opts.heavy==true; local ck=heavy and "HEAVY" or "ATTACK"
    local gate=offenseGate(ck,target,now,opts); if gate then return reject(gate,ck,f) end
    if now<(B.cooldown[ck] or 0) then return reject("COOLDOWN",ck,f) end
    local a=newAction("ATTACK",target,opts,now); a.cap="ATTACK"; a.capKey=ck; a.heavy=heavy; a.phase="TAP"; a.dmgKey=ck
    local M=RAVYN.CombatMobility; local pp=(M and M.params and M.params()) or {m1=.14}
    a.minGap=heavy and 1.0 or math.max(.06,(tonumber(pp.m1) or .14)*.85)
    local r=submit(a,"OFFENSE",now)
    if r.ok then B.cooldown[ck]=now+a.minGap; noteDispatch(a,target,now) end
    return r
end
function B:RequestSkill(skill,target,opts)
    opts=opts or {}; local now=os.clock(); B.step(now)
    target=target or LiveAction.target
    if type(skill)=="string" then skill=findSkill(skill) end
    local f=fightFor(target,now); if f then f.requests=f.requests+1 end
    if type(skill)~="table" or not skill.key then return reject("UNKNOWN_SKILL","SKILL",f) end
    local gate=offenseGate("SKILL",target,now,opts); if gate then return reject(gate,"SKILL",f,skill.key) end
    local M=RAVYN.CombatMobility
    if M and M.readiness then local r=M.readiness(skill.key,now); if r~="READY" and r~="LEARNING" then return reject("SKILL_NOT_READY","SKILL",f,skill.key.." "..tostring(r)) end end
    local ck="SKILL:"..skill.key
    if now<(B.cooldown[ck] or 0) then return reject("COOLDOWN","SKILL",f,skill.key) end
    local a=newAction("SKILL",target,opts,now); a.cap="SKILL"; a.capKey=ck; a.skill={key=skill.key,index=skill.index}; a.phase="TAP"; a.minGap=.35; a.dmgKey=ck
    local r=submit(a,"OFFENSE",now)
    if r.ok then B.cooldown[ck]=now+.35; noteDispatch(a,target,now) end
    return r
end
local function releaseGuardNow(why)
    if not B.guardDown then return true,"NOT_HELD" end
    local ok,src=true,"—"
    if B.guardBackend=="SILENT_LOCAL" then ok,src=silentInvoke(B.guardBinding,"UP")
    elseif B.guardBackend=="LEGACY_INPUT" then ok,src=LEGACY.release(B.guardKey) end
    B.guardDown=false; B.guardBackend=nil; B.guardBinding=nil
    local E=RAVYN.CombatEvolution; if E then E.guardDown=false; E.guardReleaseAt=0 end
    B.lastGuardRelease={why=why,at=os.clock(),ok=ok,src=src}
    return ok,src
end
B.releaseGuardNow=releaseGuardNow
function B:RequestGuard(enabled,target,opts)
    opts=opts or {}; local now=os.clock(); B.step(now)
    if enabled~=true then
        if not B.guardDown then return result(true,"GUARD_NOT_HELD") end
        local ok,src=releaseGuardNow(opts.source or "REQUEST")
        return result(ok,ok and "GUARD_RELEASED" or "GUARD_RELEASE_FAILED",{src=src})
    end
    local f=fightFor(target or LiveAction.target,now)
    if B.guardDown then B.guardAt=now; return result(true,"GUARD_HELD",{backend=B.guardBackend}) end
    local gate=defenseGate(now,opts); if gate then return reject(gate,"GUARD",f) end
    if now<(B.cooldown.GUARD or 0) then return reject("COOLDOWN","GUARD",f) end
    local a=newAction("GUARD",target,opts,now); a.cap="GUARD"; a.capKey="GUARD"; a.enabled=true; a.phase="DOWN"; a.minGap=.15
    local backend=B.backendFor("GUARD")
    if backend=="LEGACY_INPUT" then
        local key=opts.key; if not key then pcall(function() key=(resolveGuardKey(now)) end) end
        if not key then return reject("GUARD_KEY_UNRESOLVED","GUARD",f) end
        a.guardKey=key
    end
    local r=submit(a,"DEFENSE",now)
    if r.ok then
        B.guardDown=true; B.guardAt=now; B.guardBackend=a.backend; B.guardBinding=a.bindingRef; B.guardKey=a.guardKey
        B.cooldown.GUARD=now+.15
    end
    return r
end
function B:RequestDash(direction,target,opts)
    opts=opts or {}; local now=os.clock(); B.step(now)
    local f=fightFor(target or LiveAction.target,now)
    local gate=defenseGate(now,opts); if gate then return reject(gate,"DASH",f) end
    if now<(B.cooldown.DASH or 0) then return reject("COOLDOWN","DASH",f) end
    local a=newAction("DASH",target,opts,now); a.cap="DASH"; a.capKey="DASH"; a.direction=((tonumber(direction) or 1)<0) and -1 or 1; a.phase="TAP"; a.minGap=.5
    local r=submit(a,"DEFENSE",now)
    if r.ok then B.cooldown.DASH=now+.5; B.defenseUntil=math.max(B.defenseUntil,now+.3) end
    return r
end
function B:RequestParry(target,opts)
    opts=opts or {}; local now=os.clock(); B.step(now)
    local f=fightFor(target or LiveAction.target,now)
    local gate=defenseGate(now,opts); if gate then return reject(gate,"PARRY",f) end
    if now<(B.cooldown.PARRY or 0) then return reject("COOLDOWN","PARRY",f) end
    local a=newAction("PARRY",target,opts,now); a.cap="PARRY"; a.capKey="PARRY"; a.phase="TAP"; a.minGap=.6
    if B.backendFor("PARRY")=="LEGACY_INPUT" then
        local key=opts.key; if not key then pcall(function() key=(resolveGuardKey(now)) end) end
        if not key then return reject("PARRY_KEY_UNRESOLVED","PARRY",f) end
        a.guardKey=key
    end
    local r=submit(a,"DEFENSE",now)
    if r.ok then B.cooldown.PARRY=now+.6; B.defenseUntil=math.max(B.defenseUntil,now+.25) end
    return r
end
local function finisherKey(action) return (type(action)=="table" and action.kind=="SKILL" and action.key) and ("SKILL:"..action.key) or "ATTACK" end
-- can this finisher action be executed in the current mode? (no gates, no dispatch)
function B:CanFinish(action)
    local backend,binding,why=B.backendFor(finisherKey(action),true)
    if not backend then return false,why end
    return true,backend,binding
end
-- the ONLY finisher path: InstaKillAdapter → CombatActionBus:RequestFinisher → SilentActionAdapter (or labelled LEGACY)
function B:RequestFinisher(target,action,opts)
    opts=opts or {}; opts.finisher=true; local now=os.clock(); B.step(now)
    target=target or LiveAction.target
    local f=fightFor(target,now); if f then f.requests=f.requests+1 end
    local IK=RAVYN.InstaKillAdapter
    if not (IK and IK.locked and IK.session and IK.session.phase=="ARMED") then return reject("NO_FINISHER_SESSION","FINISHER",f) end
    local ck=finisherKey(action)
    local gate=offenseGate((ck=="ATTACK") and "ATTACK" or "SKILL",target,now,opts); if gate then return reject(gate,"FINISHER",f) end
    local a=newAction("FINISHER",target,opts,now); a.cap=(ck=="ATTACK") and "ATTACK" or "SKILL"; a.capKey=ck; a.phase="TAP"; a.minGap=.3; a.dmgKey=ck
    if ck~="ATTACK" then a.skill={key=action.key,index=action.index} end
    local r=submit(a,"OFFENSE",now)
    if r.ok then noteDispatch(a,target,now) end
    return r
end
function B.releaseAll(why)
    pcall(releaseGuardNow,why)
    for _,c in pairs(CH) do c.state="READY"; c.current=nil; c.lockUntil=0; c.readyAt=0 end
    B.pendingDmg=nil; B.defenseUntil=0
    if B.fight then B.fight.endedAt=os.clock(); B.lastFight=B.fight; B.fight=nil end
end
function B.status()
    local mode=B.mode()
    local caps={}
    for _,c in ipairs({"ATTACK","SKILL","GUARD","DASH","PARRY"}) do
        local s,why=SA.capStatus(c); local st=SA.caps[c]
        caps[c]={status=s,reason=why,binding=st and st.binding and st.binding.label or nil}
    end
    local f=B.fight or B.lastFight
    return {mode=mode,caps=caps,
        backend=(mode=="SILENT" and "SILENT_LOCAL") or (mode=="LEGACY_INPUT" and "LEGACY_INPUT") or "SILENT_LOCAL · LEGACY_INPUT per unavailable action",
        offense=CH.OFFENSE.state,defense=CH.DEFENSE.state,current=CH.OFFENSE.current or CH.DEFENSE.current,last=B.lastAction,
        fight=f,fightActive=B.fight~=nil,physicalCombat=f and f.physicalCombat or 0,physicalOther=f and f.physicalOther or 0,blocked=f and f.blocked or 0,
        execCount=B.execCount,silentCount=B.silentCount,legacyCount=B.legacyCount,finisherCount=B.finisherCount,testExecs=B.testExecs,
        lastReject=B.lastReject,testing=SA.testing,test=SA.test,lastTest=SA.lastTest,resolvedAt=SA.resolvedAt,resolveReason=SA.reason,gen=SA.gen,api=SA.api,
        guardDown=B.guardDown,legacy=RAVYN.LegacyCombatAdapter.GetStatus(),audit={total=A.total,nonBus=A.nonBus,blocked=A.blocked}}
end
function B.GetStatus() return B.status() end

-- anything still calling Hooks.pressMouse1 now goes through the bus (no direct mouse path is left)
Hooks.pressMouse1=function()
    local r=B:RequestAttack(LiveAction.target,{source="Hooks.pressMouse1"})
    return r.ok,(r.value and r.value.backend) or r.code
end

-- ================= public API =================
function RAVYN:SetCombatInputMode(m) return self:SetConfig("CombatInputMode",m) end
function RAVYN:ResolveSilentBindings() return SA.resolve("MANUAL") end
function RAVYN:VerifySilentBindings(only) return SA.verifyAll(only) end
function RAVYN:ClearSilentVerification() return SA.clearVerified() end
function RAVYN:GetCombatInputStatus() return B.status() end
local baseSetConfigV122=RAVYN.SetConfig
function RAVYN:SetConfig(path,value)
    if path=="CombatInputMode" then
        if not MODES[value] then return result(false,"UNKNOWN_COMBAT_INPUT_MODE") end
        if value~=B.mode() then B.releaseAll("MODE_CHANGE") end -- release held keys with the OLD backend first
    end
    local r=baseSetConfigV122(self,path,value)
    if r and r.ok and path=="CombatInputMode" then B.modeChangedAt=os.clock(); RAVYN.Logger:log("INFO","COMBAT_INPUT_MODE · "..tostring(value),{}) end
    return r
end

-- ================= loop: state machine · re-resolve triggers · fight tracking · guard watchdog =================
local function triggerCheck(now)
    if SA.testing then return end
    if SA.dirty then if now>=(SA.dirtyAt or 0) then SA.resolve(SA.dirty) end; return end
    if now-(SA.lastTriggerCheck or 0)<1 then return end
    SA.lastTriggerCheck=now
    local s=currentSig(); local o=SA.sig or {}
    local why=nil
    if s.char~=o.char then why="CHARACTER_ADDED"
    elseif s.tool~=o.tool then why="WEAPON_CHANGE"
    elseif s.loadout~=o.loadout then why="LOADOUT_CHANGE"
    elseif s.skills~="" and s.skills~=o.skills then why="SKILL_SET_CHANGE" end
    if why then SA.resolve(why) end
end
local function fightWatch(now)
    local t=LiveAction.target; local f=B.fight
    if f and (not t or t.id~=f.id) then
        f.goneAt=f.goneAt or now
        if now-f.goneAt>1.5 then f.endedAt=now; B.lastFight=f; B.fight=nil end
    end
    local MO=RAVYN.MoveOwner
    if t and t.id and (not B.fight or B.fight.id~=t.id) and MO and MO.current=="COMBAT_HOVER" and RAVYN.FSM and RAVYN.FSM.state=="RUNNING" then fightFor(t,now) end
end
SA.dirtyAt=os.clock()+1.5
B.token=(B.token or 0)+1
local token=B.token
task.spawn(function()
    while not RAVYN._destroyed and B.token==token do
        local now=os.clock()
        local ok,err=pcall(function()
            B.step(now)
            triggerCheck(now)
            fightWatch(now)
            if B.guardDown and now-B.guardAt>3 then releaseGuardNow("WATCHDOG") end
        end)
        if not ok then RAVYN.Logger:log("ERROR","COMBAT_BUS_TICK",{error=tostring(err)}) end
        task.wait(.05)
    end
    pcall(B.releaseAll,"DESTROYED")
end)
local baseStopV122=RAVYN.Stop
function RAVYN:Stop() B.releaseAll("STOP"); SA.testing=false; return baseStopV122(self) end
local baseDestroyV122=RAVYN.Destroy
function RAVYN:Destroy()
    B.token=B.token+1; B.releaseAll("DESTROY"); SA.testing=false
    SA.caps={}; SA.skills={}; SA.sig={}
    return baseDestroyV122(self)
end
if LP then
    table.insert(RAVYN._connections,LP.CharacterAdded:Connect(function()
        -- the old character's GUI / tool / animator are gone: drop every binding, re-resolve once the new ones exist
        B.releaseAll("RESPAWN"); SA.testing=false; SA.caps={}; SA.skills={}
        SA.dirty="CHARACTER_ADDED"; SA.dirtyAt=os.clock()+1.5
    end))
end
CTX["CombatActionBus"]=B
CTX["SilentActionAdapter"]=SA
CTX["InputAudit"]=A
CTX["CombatEvidence"]=EV
RAVYN.Logger:log("INFO","COMBAT_ACTION_BUS_V122_READY · mode "..B.mode())
return true]==========]); if not ok then return end end
do local ok=runChunk("InstaKillHardeningV122.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Util=CTX["Util"]
local Config=CTX["Config"]
local result=CTX["result"]
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local liveRoot=CTX["liveRoot"]
local targetBasis=CTX["targetBasis"]
local releaseGuard=CTX["releaseGuard"]
local D=CTX["Direct11"]
local B=CTX["CombatActionBus"]
local A=CTX["InputAudit"]
-- RAVYN DIRECT v1.2.2 · InstaKillAdapter · hardened verification
--
-- CLASS A · TRUE_ONE_HIT   : NO_VALID_PATH. trueOneHit is always false.
-- CLASS B · THRESHOLD_99   : normal combat until the target is at ≤1% HP (Threshold stays 1%) → combat locks → exactly
--                            ONE finisher → verify death → CreditProbe. PRE-ARM: when learned damage says the NEXT normal
--                            action would cross 1% (or kill from above it), that action is not sent; instead ONE action
--                            predicted to be lethal is dispatched as the finisher. The record keeps the real HP it was
--                            armed at and the trigger (HP_THRESHOLD / PRE_ARM / DAMAGE_SHARE_99) — nothing is relabelled.
-- Finisher path            : InstaKillAdapter → CombatActionBus:RequestFinisher → SilentActionAdapter (SILENT_LOCAL).
--                            SILENT without a verified local action → THRESHOLD_FINISHER_SILENT_UNAVAILABLE (no lock, no
--                            input). HYBRID may use the single legacy finisher, labelled THRESHOLD_FINISHER_LEGACY_INPUT.
-- Verification             : UNTESTED → TESTING → PROBATION → VERIFIED (or FAILED). One kill never verifies. VERIFIED needs
--                            6 qualifying finishers IN A ROW including ≥3 normal mobs, ≥2 different bosses and ≥1 high-HP
--                            boss. A qualifying test = exactly 1 finisher dispatch, 0 other inputs during verify, confirmed
--                            death AND a credit signal (KILL_AND_CREDIT). NO_KILL / KILL_ONLY / INVALID_VERIFICATION reset
--                            the streak. AUTO stays MAX_BURST until VERIFIED. Only VERIFIED is persisted.
local defaults={Mode="AUTO",Threshold=0.01,ArmDelay=.3,VerifyWindow=2.5,RangeWait=1.5,FinisherAction="AUTO",CreditWindow=8,
    PreArm=true,PreArmMargin=1.15,LethalMargin=1.1,HighHpBossMinMaxHealth=10000,
    RequiredStreak=6,RequiredNormal=3,RequiredBosses=2,RequiredHighHp=1,
    VerificationStatus="UNTESTED",VerifiedAt=0,VerifiedBackend="",VerifiedMatrix="",
    ThresholdVerifiedAt=0,ThresholdSuccesses=0,ThresholdFailures=0} -- last three: v1.2.1 keys, kept only to be cleared
Config.Default.InstaKill=Util.deepCopy(defaults)
RAVYN.Config.InstaKill=Util.deepMerge(defaults,RAVYN.Config.InstaKill or {})
local function ic() return RAVYN.Config.InstaKill end
local MODES={AUTO=true,THRESHOLD_99=true,MAX_BURST=true}
local VSTATES={UNTESTED=true,TESTING=true,PROBATION=true,VERIFIED=true,FAILED=true}
local LP=game:GetService("Players").LocalPlayer

local IK={locked=false,session=nil,records={},tried={},retryAt={},phase="IDLE",engaged=nil,pending={},seenResolutions=0,
    wenInst=nil,wenAt=-math.huge,wenFrame=nil,wenFrameAt=-math.huge,blockReason=nil}
RAVYN.InstaKillAdapter=IK
local V={streak={},tests={},queue={},testsRun=0,lethalSuccesses=0,creditSuccesses=0,misses=0,invalid=0,killOnly=0,
    diedBeforeFinisher=0,notLethal=0,windowSkips=0,failedLast=false,lastResult=nil}
IK.V=V

-- ================= migration: v1.2.1 verified after ONE kill → discarded =================
local function migrate()
    local c=ic()
    if not MODES[c.Mode] then c.Mode="AUTO" end
    local th=tonumber(c.Threshold) or .01; if th>.01 then th=.01 end; if th<.001 then th=.001 end; c.Threshold=th -- THRESHOLD_99 means ≤1%
    if (tonumber(c.ThresholdVerifiedAt) or 0)>0 or (tonumber(c.ThresholdSuccesses) or 0)>0 or (tonumber(c.ThresholdFailures) or 0)>0 then
        c.ThresholdVerifiedAt=0; c.ThresholdSuccesses=0; c.ThresholdFailures=0
        IK.migratedFrom121=true
        RAVYN.Logger:log("WARN","INSTAKILL · v1.2.1 single-kill verification discarded · v1.2.2 requires the full test matrix",{})
    end
    if not VSTATES[c.VerificationStatus] then c.VerificationStatus="UNTESTED" end
    if c.VerificationStatus=="TESTING" or c.VerificationStatus=="PROBATION" then c.VerificationStatus="UNTESTED" end -- session states are never persisted
    if c.VerificationStatus=="VERIFIED" and not ((tonumber(c.VerifiedAt) or 0)>0 and tostring(c.VerifiedMatrix or "")~="") then
        c.VerificationStatus="UNTESTED"; c.VerifiedAt=0
    end
end
migrate()
local baseLoadV122=RAVYN.LoadSettings
function RAVYN:LoadSettings(...)
    local r=baseLoadV122(self,...)
    pcall(migrate)
    return r
end

-- ================= reads (local only) =================
local function playerGui() return LP and LP:FindFirstChildOfClass("PlayerGui") end
local function humOf(target)
    local RA=RAVYN.ReadAdapter; local raw=RA and RA.lastEntities and target and RA.lastEntities[target.id]
    if not raw then return nil,nil end
    local ok,h=pcall(function() return RA:_entityHumanoid(raw) end)
    return (ok and h) or nil,raw
end
local function hpOf(h)
    if not h then return nil end
    local ok,hp,mx=pcall(function() return h.Health,h.MaxHealth end)
    if ok and tonumber(hp) and tonumber(mx) and mx>0 then return hp/mx,hp,mx end
    return nil
end
-- trace #001: PlayerGui.BossUi.MainHolder.CanvasGroup.<LocalPlayer>.Holder.Txt = "2,999.99 (99%)"
local function bossDamageShare(target)
    local pg=playerGui(); local bu=pg and pg:FindFirstChild("BossUi"); if not bu then return nil end
    local id=bu:FindFirstChild("Identity"); id=id and id:FindFirstChild("Holder"); id=id and id:FindFirstChild("zText"); id=id and id:FindFirstChild("Txt")
    if id and target and D.trim(id.Text)~=tostring(target.name) then return nil end
    local t=bu:FindFirstChild("MainHolder"); t=t and t:FindFirstChild("CanvasGroup"); t=t and LP and t:FindFirstChild(LP.Name); t=t and t:FindFirstChild("Holder"); t=t and t:FindFirstChild("Txt")
    return t and tonumber(string.match(t.Text or "","%((%d+)%%%)")) or nil
end
local function dataRoots()
    local SCH=RAVYN.RuntimeSchema; if not (SCH and SCH.get) then return {} end
    local n=SCH.get().nodes or {}; return {n.sectionRoot,n.playerData}
end
local function progressVals()
    local out={}
    for _,r in ipairs(dataRoots()) do
        if r and r.Parent then
            local pr=r:FindFirstChild("Progress")
            if pr then
                for _,k in ipairs({"kills","boss_kills","chests"}) do
                    local v=pr:FindFirstChild(k); if v and v:IsA("ValueBase") then out[k]=tonumber(v.Value) end
                end
                return out
            end
        end
    end
    return out
end
local function wenValue(now)
    if IK.wenInst and IK.wenInst.Parent then return tonumber(IK.wenInst.Value) end
    if now-IK.wenAt<60 then return nil end
    IK.wenAt=now
    for _,r in ipairs(dataRoots()) do
        if r and r.Parent then
            local queue={{r,0}}; local head,n=1,0
            while head<=#queue and n<400 do
                local node,depth=queue[head][1],queue[head][2]; head=head+1; n=n+1
                if node:IsA("ValueBase") and string.lower(node.Name)=="wen" then IK.wenInst=node; return tonumber(node.Value) end
                if depth<3 then for _,c in ipairs(node:GetChildren()) do table.insert(queue,{c,depth+1}) end end
            end
        end
    end
    return nil
end
local function wenPopup(now)
    if not (IK.wenFrame and IK.wenFrame.Parent) then
        if now-IK.wenFrameAt<30 then return nil end
        IK.wenFrameAt=now
        local pg=playerGui(); local ok,f=pcall(function() return pg and pg:FindFirstChild("WenFrame",true) end)
        IK.wenFrame=ok and f or nil
        if not IK.wenFrame then return nil end
    end
    for i,d in ipairs(IK.wenFrame:GetDescendants()) do
        if i>40 then break end
        if d:IsA("TextLabel") and string.match(d.Text or "","^%+%d") then return d.Text end
    end
    return nil
end
local function counters(now)
    local p=progressVals(); local RA=RAVYN.ReadAdapter
    local x=RA and RA:getXP(); local l=RA and RA:getLevel()
    return {kills=p.kills,bossKills=p.boss_kills,chests=p.chests,exp=(x and x.ok) and x.value or nil,level=(l and l.ok) and l.value or nil,wen=wenValue(now)}
end
local function promptShown(name)
    local pg=playerGui(); if not pg then return false end
    local h=pg:FindFirstChild("PromptsHolder") or pg
    local g=h:FindFirstChild(name)
    if not g then return false end
    if g:IsA("LayerCollector") then return g.Enabled end
    if g:IsA("GuiObject") then return g.Visible end
    return true
end
local function isBoss(t) return t and (t.isBoss==true or t.classification=="BOSS") or false end

-- ================= verification matrix =================
local function matrix()
    local m={normal=0,boss=0,distinct=0,highHp=0,streak=#V.streak}
    local names={}
    for _,t in ipairs(V.streak) do
        if t.boss then
            m.boss=m.boss+1
            if not names[t.name] then names[t.name]=true; m.distinct=m.distinct+1 end
            if t.highHp then m.highHp=m.highHp+1 end
        else m.normal=m.normal+1 end
    end
    return m
end
local function compositionMet(m)
    local c=ic()
    return m.normal>=(tonumber(c.RequiredNormal) or 3) and m.distinct>=(tonumber(c.RequiredBosses) or 2) and m.highHp>=(tonumber(c.RequiredHighHp) or 1)
end
local function missing(m)
    local c=ic(); local out={}
    local n=(tonumber(c.RequiredNormal) or 3)-m.normal; if n>0 then table.insert(out,n.." normal mob"..(n==1 and "" or "s")) end
    local b=(tonumber(c.RequiredBosses) or 2)-m.distinct; if b>0 then table.insert(out,b.." different boss"..(b==1 and "" or "es")) end
    if (tonumber(c.RequiredHighHp) or 1)-m.highHp>0 then table.insert(out,"1 high-HP boss") end
    local s=(tonumber(c.RequiredStreak) or 6)-m.streak; if s>0 then table.insert(out,s.." more pass"..(s==1 and "" or "es").." in a row") end
    return out
end
function IK.verificationStatus()
    local c=ic()
    if c.VerificationStatus=="VERIFIED" and (tonumber(c.VerifiedAt) or 0)>0 then return "VERIFIED" end
    if V.failedLast then return "FAILED" end
    if V.testsRun==0 then return (c.VerificationStatus=="FAILED") and "FAILED" or "UNTESTED" end
    if #V.streak>0 and compositionMet(matrix()) then return "PROBATION" end
    return "TESTING"
end
local function modeBackendClass()
    local m=B.mode()
    return (m=="SILENT" and "SILENT_LOCAL") or (m=="LEGACY_INPUT" and "LEGACY_INPUT") or "HYBRID"
end
-- a verification is only reused with the kind of finisher backend it was earned with
local function backendCompatible()
    local cls=modeBackendClass()
    if cls=="HYBRID" then return true end
    return tostring(ic().VerifiedBackend or "")==cls
end
function IK.activeClass()
    local m=ic().Mode
    if m=="MAX_BURST" then return "MAX_BURST" end
    if m=="THRESHOLD_99" then return "THRESHOLD_99" end -- explicit choice = test mode
    if IK.verificationStatus()=="VERIFIED" and backendCompatible() then return "THRESHOLD_99" end
    return "MAX_BURST" -- AUTO: never THRESHOLD_99 before the whole matrix passed
end

-- ================= finisher selection (learned damage from the CombatActionBus) =================
local function range(action)
    local p=(Hooks.activeProfile and Hooks.activeProfile()) or {}
    if action and action.kind=="SKILL" then return math.max((p.attackDistance or 9)+10,18) end
    return math.max((p.attackDistance or 9)+1.5,12)
end
local function readySkills(now)
    local out={}
    local M=RAVYN.CombatMobility
    if M and M.skillKeys and M.readiness and RAVYN.Config.Combat.AutoAbilities then
        for _,k in ipairs(M.skillKeys) do local r=M.readiness(k.key,now); if r=="READY" or r=="LEARNING" then table.insert(out,k) end end
    end
    return out
end
-- actions the bus can execute as a finisher in the current mode (SILENT: verified local action only)
local function actionCandidates(now)
    local want=ic().FinisherAction; local list={}
    if want~="SKILL" then table.insert(list,{kind="M1",pred=(B.predict("ATTACK")),maxd=B.predictMax("ATTACK"),label="M1"}) end
    if want~="M1" then for _,k in ipairs(readySkills(now)) do table.insert(list,{kind="SKILL",key=k.key,index=k.index,pred=(B.predict("SKILL",k.key)),maxd=B.predictMax("SKILL",k.key),label="SKILL "..k.key}) end end
    local out={}
    for _,a in ipairs(list) do local ok,backend=B:CanFinish(a); if ok then a.backend=backend; table.insert(out,a) end end
    return out
end
-- exactly ONE action predicted to be lethal for hp fraction h:
--   1) the smallest average damage that covers h × LethalMargin   (MARGIN)
--   2) the largest average damage that still covers h              (AVERAGE)
--   3) the largest damage this action has actually dealt ≥ h       (OBSERVED_MAX)
local function pickLethal(h,cands)
    local margin=tonumber(ic().LethalMargin) or 1.1
    local confident,likely,capable=nil,nil,nil
    for _,a in ipairs(cands) do
        if a.pred and a.pred>=h*margin and (not confident or a.pred<confident.pred) then confident=a end
        if a.pred and a.pred>=h and (not likely or a.pred>likely.pred) then likely=a end
        if a.maxd and a.maxd>=h and (not capable or a.maxd>capable.maxd) then capable=a end
    end
    if confident then confident.confidence="MARGIN"; return confident end
    if likely then likely.confidence="AVERAGE"; return likely end
    if capable then capable.confidence="OBSERVED_MAX"; return capable end
    return nil
end
-- the biggest damage the NEXT normal action could do (M1 or any ready skill)
local function nextNormalDamage(now)
    local best=(B.predict("ATTACK"))
    if RAVYN.Config.Combat.AutoAbilities then
        for _,k in ipairs(readySkills(now)) do local d=(B.predict("SKILL",k.key)); if d and (not best or d>best) then best=d end end
    end
    return best
end

-- ================= records =================
local function pct(x) return x and string.format("%.1f%%",x*100) or "?" end
local function describe(r)
    local function pair(a,b) return (a~=nil and b~=nil) and (tostring(a).."→"..tostring(b)) or "?" end
    local who=tostring(r.target or "?")..(r.boss and " ◆" or "")..(r.highHp and " HIGH-HP" or "")
    if not r.finisher then
        return string.format("%s · NORMAL KILL · %s · kills %s · boss %s · exp %s · chest %s · loot %s · %s",who,tostring(r.death or "no death"),
            pair(r.before.kills,r.after and r.after.kills),pair(r.before.bossKills,r.after and r.after.bossKills),
            (r.levelUp and "level-up") or (r.expGain and ("+"..r.expGain)) or "?",r.chestPrompt and "yes" or "no",r.lootPrompt and "yes" or "no",tostring(r.credit or "PENDING"))
    end
    return string.format("%s · FINISHER %s [%s] · trigger %s · HP before %s · predicted %s · dispatch %s · inputs during verify %s · death %s · kills %s · boss %s · exp %s · wen %s · chest %s · loot %s · %s",
        who,tostring(r.action),tostring(r.backend or "?"),tostring(r.trigger or "?"),pct(r.hpBefore),pct(r.predicted),
        tostring(r.finisherDispatchCount or "?"),tostring(r.inputsDuringVerify or "?"),tostring(r.death or "none"),
        pair(r.before.kills,r.after and r.after.kills),pair(r.before.bossKills,r.after and r.after.bossKills),
        (r.levelUp and "level-up") or (r.expGain and ("+"..r.expGain)) or "?",(r.wenGain and ("+"..r.wenGain)) or (r.wenPopup and tostring(r.wenPopup)) or "?",
        r.chestPrompt and "yes" or "no",r.lootPrompt and "yes" or "no",tostring(r.classification or r.credit or "PENDING"))
end
IK.describe=describe
local function creditOf(r)
    if not r.death then return "NO_KILL" end
    local a=r.after or {}; local b=r.before or {}
    local killsUp=(a.kills and b.kills and a.kills>b.kills) or false
    local bossUp=(a.bossKills and b.bossKills and a.bossKills>b.bossKills) or false
    local expUp=r.levelUp==true or (tonumber(r.expGain) or 0)>0
    local wenUp=(tonumber(r.wenGain) or 0)>0 or (r.wenPopup~=nil)
    if killsUp or bossUp or expUp or wenUp or r.chestPrompt or r.lootPrompt then return "KILL_AND_CREDIT" end
    return "KILL_ONLY"
end
local function pushRecord(r) table.insert(IK.records,r); while #IK.records>12 do table.remove(IK.records,1) end end
local function persistVerified(m)
    local seen,n,only={},0,nil
    for _,t in ipairs(V.streak) do if not seen[t.backend or "?"] then seen[t.backend or "?"]=true; n=n+1; only=t.backend or "?" end end
    local backend=(n==1) and only or "MIXED"
    local summary=string.format("%d in a row · %d normal · %d boss kills (%d different) · %d high-HP · %s",m.streak,m.normal,m.boss,m.distinct,m.highHp,backend)
    pcall(function() RAVYN:SetConfig("InstaKill.VerifiedBackend",backend) end)
    pcall(function() RAVYN:SetConfig("InstaKill.VerifiedMatrix",summary) end)
    pcall(function() RAVYN:SetConfig("InstaKill.VerifiedAt",os.time()) end)
    pcall(function() RAVYN:SetConfig("InstaKill.VerificationStatus","VERIFIED") end)
    RAVYN.Logger:log("INFO","INSTAKILL · THRESHOLD_99 VERIFIED · "..summary,{})
    D.event("Insta Kill · THRESHOLD_99 VERIFIED · "..summary,"success")
end
local function demote(cls)
    pcall(function() RAVYN:SetConfig("InstaKill.VerifiedAt",0) end)
    pcall(function() RAVYN:SetConfig("InstaKill.VerificationStatus","FAILED") end)
    D.event("Insta Kill · verification withdrawn (finisher "..cls..") · AUTO is MAX BURST again","warn")
end
-- a finished test counts in dispatch order (a later miss can never be applied before an earlier pass)
local function applyTest(r)
    V.testsRun=V.testsRun+1
    local cls=r.classification
    if cls=="KILL_AND_CREDIT" then
        V.creditSuccesses=V.creditSuccesses+1; V.failedLast=false
        table.insert(V.streak,{name=r.target,boss=r.boss,highHp=r.highHp,backend=r.backend})
        r.streakAfter=#V.streak
        local m=matrix(); local c=ic()
        if c.VerificationStatus~="VERIFIED" and m.streak>=(tonumber(c.RequiredStreak) or 6) and compositionMet(m) then persistVerified(m) end
    else
        if cls=="NO_KILL" then V.misses=V.misses+1 elseif cls=="KILL_ONLY" then V.killOnly=V.killOnly+1 elseif cls=="INVALID_VERIFICATION" then V.invalid=V.invalid+1 end
        V.streak={}; r.streakAfter=0
        if cls=="NO_KILL" or cls=="KILL_ONLY" then
            V.failedLast=true
            if ic().VerificationStatus=="VERIFIED" then demote(cls) end
        end
    end
    table.insert(V.tests,r); while #V.tests>20 do table.remove(V.tests,1) end
    V.lastResult=r
    RAVYN.Logger:log(cls=="KILL_AND_CREDIT" and "INFO" or "WARN","INSTAKILL_TEST · "..describe(r),{})
end
local function drainQueue()
    while V.queue[1] and V.queue[1].ready do applyTest(table.remove(V.queue,1)) end
end
local function startCredit(r,now)
    r.deathAt=now; r.credit="PENDING"
    local LB=RAVYN.BossLootV2
    r.lootChestsBefore=LB and LB.stats and LB.stats.chestsOpened or 0
    r.lootItemsBefore=LB and LB.stats and LB.stats.items or 0
    table.insert(IK.pending,r); pushRecord(r)
end
local function creditStep(now)
    for i=#IK.pending,1,-1 do
        local r=IK.pending[i]
        r.chestPrompt=r.chestPrompt or promptShown("ChestPrompt")
        r.lootPrompt=r.lootPrompt or promptShown("LootDropPrompt")
        r.wenPopup=r.wenPopup or wenPopup(now)
        if now-r.deathAt>=(ic().CreditWindow or 8) then
            r.after=counters(now)
            local LB=RAVYN.BossLootV2
            if LB and LB.stats then
                if (LB.stats.chestsOpened or 0)>r.lootChestsBefore then r.chestPrompt=true end
                if (LB.stats.items or 0)>r.lootItemsBefore then r.lootPrompt=true end
            end
            if r.after.level and r.before.level and r.after.level>r.before.level then r.levelUp=true
            elseif r.after.exp and r.before.exp then r.expGain=r.after.exp-r.before.exp end
            if r.after.wen and r.before.wen then r.wenGain=r.after.wen-r.before.wen end
            r.credit=creditOf(r)
            if r.finisher then r.classification=r.classification or r.credit; r.ready=true end
            r.text=describe(r)
            RAVYN.Logger:log("INFO","LOOT · credit · "..r.text,{})
            table.remove(IK.pending,i)
        end
    end
    drainQueue()
end

-- ================= finisher session =================
local function release(reason)
    local s=IK.session
    if s and s.conn then pcall(function() s.conn:Disconnect() end) end
    IK.session=nil; IK.locked=false; IK.phase="IDLE"; IK.lastRelease=reason
end
local function lock(t,h,raw,f,mx,now,why,action,predNext,inflight)
    IK.tried[t.id]=now
    local boss=isBoss(t)
    local s={id=t.id,name=t.name,boss=boss,maxHealth=mx,highHp=(boss and mx and mx>=(tonumber(ic().HighHpBossMinMaxHealth) or 10000)) or false,
        hum=h,raw=raw,phase="ARMED",at=now,hpArmed=f,trigger=why,action=action,predictedNext=predNext,inflight=inflight,
        share=boss and bossDamageShare(t) or nil,finAtArm=B.finisherCount}
    if h then
        local ok,c=pcall(function() return h.Died:Connect(function() if IK.session==s then s.died=s.died or "Humanoid.Died" end end) end)
        if ok then s.conn=c end
    end
    IK.session=s; IK.locked=true; IK.phase="ARMED"
    pcall(function() if releaseGuard then releaseGuard() end end) -- before the finisher, never during verify
    return s
end
local function deathOf(s)
    if s.died then return s.died end
    local f,hp=hpOf(s.hum)
    if hp and hp<=0 then return "HealthZero" end
    if (s.raw and not s.raw.Parent) or (s.hum and not s.hum.Parent) then return "Removed" end
    return nil
end
local function newRecord(s,now)
    local a=s.action or {}
    return {target=s.name,boss=s.boss,highHp=s.highHp,maxHealth=s.maxHealth,finisher=true,trigger=s.trigger,
        action=(a.kind=="SKILL" and ("SKILL "..tostring(a.key))) or "M1",predicted=a.pred,predictedMax=a.maxd,confidence=a.confidence,predictedNext=s.predictedNext,inflight=s.inflight,
        backend=s.backend,label=s.label,binding=s.binding,hpArmed=s.hpArmed,hpBefore=s.hpBefore,share=s.share,before=s.before or {},at=now,mode=B.mode()}
end
local function finishSession(s,now,death)
    local r=newRecord(s,now)
    r.finisherDispatchCount=B.finisherCount-(s.finAtArm or 0)
    r.busActionsDuringVerify=B.execCount-(s.execAtDispatch or B.execCount)
    r.otherInputsDuringVerify=A.nonBus-(s.nonBusAtDispatch or A.nonBus)
    r.inputsDuringVerify=r.busActionsDuringVerify+r.otherInputsDuringVerify
    r.physicalDuringVerify=A.total-(s.physAtDispatch or A.total)
    r.blockedDuringVerify=A.blocked-(s.blockedAtDispatch or A.blocked)
    r.death=death
    local f=hpOf(s.hum); r.hpAfter=f or (death and 0) or nil
    r.valid=r.finisherDispatchCount==1 and r.inputsDuringVerify==0 and r.physicalDuringVerify==0 and r.blockedDuringVerify==0
    table.insert(V.queue,r)
    if not r.valid then
        r.classification="INVALID_VERIFICATION"; r.credit="INVALID_VERIFICATION"; r.ready=true
        r.text=describe(r); pushRecord(r)
    elseif death then
        V.lethalSuccesses=V.lethalSuccesses+1
        startCredit(r,now) -- classified after the CreditWindow
    else
        r.classification="NO_KILL"; r.credit="NO_KILL"; r.ready=true
        r.text=describe(r); pushRecord(r)
    end
    IK.lastFinisher=r
    if death then D.event("Insta Kill · finisher killed "..tostring(s.name).." ("..death..") · checking credit","success")
    else D.event("Insta Kill · finisher did not kill "..tostring(s.name).." · normal combat resumes","warn") end
    release(death and "KILLED" or "NO_KILL")
    drainQueue()
end
local function sessionStep(now)
    local s=IK.session; if not s then return end
    if not D.running() then release("STOPPED"); return end
    if s.phase=="ARMED" then
        local t=LiveAction.target
        if not t or t.id~=s.id then release("TARGET_CHANGED"); return end
        local death=deathOf(s)
        if death then
            -- an action already in flight killed it: no finisher was sent → not a test (credit-probed for comparison)
            V.diedBeforeFinisher=V.diedBeforeFinisher+1
            local r=newRecord(s,now); r.finisher=false; r.death=death; r.note="died before the finisher"
            r.before=(IK.engaged and IK.engaged.id==s.id and IK.engaged.before) or {}
            startCredit(r,now); release("DIED_BEFORE_FINISHER"); return
        end
        if now-s.at<(ic().ArmDelay or .3) then return end
        local f=hpOf(s.hum)
        if s.trigger=="PRE_ARM" and f then
            -- in-flight damage has landed: the ONE finisher must still be predicted lethal for the settled HP
            local a=pickLethal(f,actionCandidates(now))
            if not a then V.notLethal=V.notLethal+1; IK.tried[s.id]=nil; IK.retryAt[s.id]=now+2; release("NOT_LETHAL_AFTER_SETTLE"); return end
            s.action=a
        end
        local root=liveRoot(); local tp=targetBasis(t)
        local d=(root and tp) and (root.Position-tp).Magnitude or math.huge
        local rng=range(s.action)
        if d>rng then
            if now-s.at>(ic().RangeWait or 1.5)+(ic().ArmDelay or .3) then IK.tried[s.id]=nil; IK.retryAt[s.id]=now+2; release("OUT_OF_RANGE") end
            return
        end
        s.hpBefore=f or s.hpArmed
        s.before=counters(now)
        local physBefore=A.total
        local r=B:RequestFinisher(t,s.action,{source="InstaKillAdapter",range=rng})
        if not r.ok then
            if (B.CAP_CODES and B.CAP_CODES[r.code]) or r.code=="NO_FINISHER_SESSION" then
                IK.blockReason=r.code; IK.tried[s.id]=nil; IK.retryAt[s.id]=now+3; release("FINISHER_REFUSED:"..tostring(r.code))
            end
            return -- transient (ACTION_LOCK / COOLDOWN): nothing was sent, try again next tick
        end
        s.backend=r.value and r.value.backend; s.label=r.value and r.value.label; s.binding=r.value and r.value.binding
        s.sentAt=now; s.phase="VERIFY"; IK.phase="VERIFY"
        -- baselines taken AFTER the one finisher dispatch: everything counted from here on is "during verify"
        s.execAtDispatch=B.execCount; s.physAtDispatch=A.total; s.nonBusAtDispatch=A.nonBus; s.blockedAtDispatch=A.blocked
        s.physFinisher=A.total-physBefore
        return
    end
    if s.phase=="VERIFY" then
        local death=deathOf(s)
        if death then finishSession(s,now,death); return end
        if now-s.sentAt>(ic().VerifyWindow or 2.5) then finishSession(s,now,nil) end
    end
end
local function armStep(now)
    if IK.session then IK.armWhy="SESSION"; return end
    if IK.activeClass()~="THRESHOLD_99" or not D.running() then IK.blockReason=nil; IK.armWhy="CLASS_"..IK.activeClass(); return end
    local SA=RAVYN.SilentActionAdapter; if SA and SA.testing then IK.armWhy="SILENT_TEST"; return end
    local t=LiveAction.target; if not (t and t.id) then IK.armWhy="NO_TARGET"; return end
    if IK.tried[t.id] and now-IK.tried[t.id]<60 then IK.armWhy="ALREADY_TESTED_THIS_TARGET"; return end
    if IK.retryAt[t.id] and now<IK.retryAt[t.id] then IK.armWhy="RETRY_WAIT"; return end
    local MO=RAVYN.MoveOwner; if not (MO and MO.current=="COMBAT_HOVER") then IK.armWhy="NOT_IN_COMBAT_HOVER"; return end
    local h,raw=humOf(t); local f,_,mx=hpOf(h)
    if f and f<=0 then IK.armWhy="TARGET_DEAD"; return end
    local c=ic(); local th=tonumber(c.Threshold) or .01
    local why,predNext,inflight=nil,nil,0
    if f then
        if f<=th then why="HP_THRESHOLD"
        elseif c.PreArm then
            predNext=nextNormalDamage(now); inflight=B.inflight(t,now)
            if predNext and (f-inflight)-predNext*(tonumber(c.PreArmMargin) or 1.15)<=th then why="PRE_ARM" end
        end
    elseif isBoss(t) then
        -- real HP unreadable: the boss damage share is the fallback (never used while real HP is readable)
        local share=bossDamageShare(t)
        if share and share>=99 then why="DAMAGE_SHARE_99" end
    end
    if not why then IK.armWhy=f and string.format("WATCHING %.1f%%",f*100) or "HP_UNREADABLE"; return end
    local cands=actionCandidates(now)
    if #cands==0 then IK.blockReason=(B.mode()=="SILENT") and "THRESHOLD_FINISHER_SILENT_UNAVAILABLE" or "THRESHOLD_FINISHER_UNAVAILABLE"; IK.armWhy=IK.blockReason; return end
    IK.blockReason=nil
    local action
    if why=="PRE_ARM" then
        -- the next normal action would cross 1%: it is NOT sent. If one action is predicted lethal it becomes the
        -- finisher; if none is, the next normal action is predicted to land inside the window (not kill) → allowed.
        action=pickLethal(f,cands)
        if not action then IK.armWhy=string.format("PRE_ARM_NO_LETHAL %.1f%%",f*100); return end
    else
        action=pickLethal(f or th,cands) or cands[1]
    end
    lock(t,h,raw,f,mx,now,why,action,predNext,inflight)
end
-- synchronous check from the combat executor right before every normal attack decision
function IK.preAttack(target,now)
    if IK.session then return IK.locked end
    local ok=pcall(armStep,now or os.clock())
    return ok and IK.locked or false
end
local function engageStep(now)
    local t=LiveAction.target
    if t and t.id and (not IK.engaged or IK.engaged.id~=t.id) then
        IK.engaged={id=t.id,name=t.name,boss=isBoss(t),before=counters(now),at=now,cls=IK.activeClass()}
    end
    local AP=RAVYN.AutoPlay384; local Hh=AP and AP.handoff
    if Hh and (Hh.resolutions or 0)>IK.seenResolutions then
        IK.seenResolutions=Hh.resolutions or 0
        local e=IK.engaged
        local finisherOwned=(IK.session and e and IK.session.id==e.id) or (IK.lastFinisher and IK.lastFinisher.at and now-IK.lastFinisher.at<1 and IK.lastFinisher.death)
        if e and not finisherOwned then
            -- died from a normal action while the finisher was active and before any finisher was tried on it
            if (e.cls=="THRESHOLD_99" or IK.activeClass()=="THRESHOLD_99") and not IK.tried[e.id] then V.windowSkips=V.windowSkips+1 end
            startCredit({target=e.name,boss=e.boss,finisher=false,action="—",death=tostring(Hh.deathBy or "RESOLVED"),before=e.before or {},at=now},now)
        end
        IK.engaged=nil
    end
end

-- ================= public API =================
function IK.CanUse(target)
    target=target or LiveAction.target
    if not target then return false,"NO_TARGET" end
    if IK.activeClass()~="THRESHOLD_99" then return false,"MODE_"..IK.activeClass() end
    local h=humOf(target); local f=hpOf(h)
    if not f then return false,"HP_UNREADABLE" end
    if f<=0 then return false,"ALREADY_DEAD" end
    if f>(tonumber(ic().Threshold) or .01) then return false,"ABOVE_THRESHOLD" end
    if #actionCandidates(os.clock())==0 then return false,(B.mode()=="SILENT") and "THRESHOLD_FINISHER_SILENT_UNAVAILABLE" or "THRESHOLD_FINISHER_UNAVAILABLE" end
    local root=liveRoot(); local tp=targetBasis(target)
    if not (root and tp) or (root.Position-tp).Magnitude>range() then return false,"OUT_OF_RANGE" end
    if IK.session then return false,"BUSY" end
    return true,"READY"
end
function IK.Execute(target)
    target=target or LiveAction.target
    local ok,why=IK.CanUse(target); if not ok then return result(false,why) end
    local h,raw=humOf(target); local f,_,mx=hpOf(h)
    local cands=actionCandidates(os.clock())
    local s=lock(target,h,raw,f,mx,os.clock(),"MANUAL",pickLethal(f,cands) or cands[1],nil,0)
    s.at=os.clock()-(ic().ArmDelay or .3)
    return result(true,"FINISHER_ARMED")
end
function IK.Verify(target)
    local s=IK.session
    if s and target and s.id==target.id then return result(true,s.phase,{death=deathOf(s)}) end
    local r=IK.lastFinisher
    return result(r~=nil,r and (r.classification or (r.death and "KILLED" or "NO_KILL")) or "NO_FINISHER",r)
end
local function finisherPath()
    local ok,backend=B:CanFinish({kind="M1"})
    local SA=RAVYN.SilentActionAdapter
    if not ok and SA then for key,st in pairs(SA.skills or {}) do local ok2,b2=B:CanFinish({kind="SKILL",key=key}); if ok2 then ok,backend=true,b2; break end end end
    if not ok then return false,nil,(B.mode()=="SILENT") and "THRESHOLD_FINISHER_SILENT_UNAVAILABLE" or "THRESHOLD_FINISHER_UNAVAILABLE" end
    return true,backend,(backend=="SILENT_LOCAL") and "THRESHOLD_FINISHER_SILENT" or "THRESHOLD_FINISHER_LEGACY_INPUT"
end
function IK.GetStatus()
    local c=ic(); local m=matrix(); local vs=IK.verificationStatus()
    local req=tonumber(c.RequiredStreak) or 6
    local okF,backend,label=finisherPath()
    return {available=okF,mode=c.Mode,activeClass=IK.activeClass(),trueOneHit=false,trueOneHitStatus="NO_VALID_PATH",
        thresholdFinisher=IK.activeClass()=="THRESHOLD_99",threshold=tonumber(c.Threshold) or .01,
        verificationStatus=vs,statusText=(vs=="VERIFIED") and "THRESHOLD_99 VERIFIED" or ("THRESHOLD_99 · "..vs.." · "..m.streak.."/"..req),
        testsRequired=req,testsPassed=V.creditSuccesses,consecutivePassed=m.streak,
        normalMobPassed=m.normal,bossPassed=m.boss,bossDistinct=m.distinct,highHpBossPassed=m.highHp,
        lethalSuccesses=V.lethalSuccesses,creditSuccesses=V.creditSuccesses,misses=V.misses,invalidVerifications=V.invalid,killOnly=V.killOnly,
        testsRun=V.testsRun,diedBeforeFinisher=V.diedBeforeFinisher,windowSkips=V.windowSkips,notLethal=V.notLethal,missing=missing(m),
        required={normal=tonumber(c.RequiredNormal) or 3,bosses=tonumber(c.RequiredBosses) or 2,highHp=tonumber(c.RequiredHighHp) or 1,streak=req,highHpMin=tonumber(c.HighHpBossMinMaxHealth) or 10000},
        verifiedAt=c.VerifiedAt,verifiedBackend=c.VerifiedBackend,verifiedMatrix=c.VerifiedMatrix,backendCompatible=backendCompatible(),
        finisherBackend=backend,finisherLabel=label,silent=backend=="SILENT_LOCAL",blockReason=IK.blockReason,
        phase=IK.phase,locked=IK.locked,last=IK.lastFinisher,lastTest=V.lastResult,migratedFrom121=IK.migratedFrom121==true,
        -- v1.2.1 field names kept for older UI code
        thresholdStatus="THRESHOLD_99_"..vs,successes=V.creditSuccesses,failures=V.misses}
end
IK.GetInstaKillStatus=IK.GetStatus
function RAVYN:GetInstaKillStatus() return IK.GetStatus() end
function RAVYN:SetInstaKillMode(m)
    if not MODES[m] then return result(false,"UNKNOWN_INSTAKILL_MODE") end
    if m~="THRESHOLD_99" and IK.session and IK.session.phase=="ARMED" then release("MODE_CHANGED") end
    return self:SetConfig("InstaKill.Mode",m)
end
function RAVYN:SetInstaKillHighHp(n)
    n=tonumber(n); if not n or n<1 then return result(false,"INVALID_HIGH_HP") end
    return self:SetConfig("InstaKill.HighHpBossMinMaxHealth",n)
end
function RAVYN:ResetInstaKillVerification()
    V.streak={}; V.tests={}; V.queue={}; V.testsRun=0; V.lethalSuccesses=0; V.creditSuccesses=0; V.misses=0; V.invalid=0; V.killOnly=0
    V.diedBeforeFinisher=0; V.notLethal=0; V.windowSkips=0; V.failedLast=false; V.lastResult=nil
    IK.tried={}; IK.retryAt={}; IK.lastFinisher=nil
    pcall(function() self:SetConfig("InstaKill.VerifiedAt",0) end)
    pcall(function() self:SetConfig("InstaKill.VerifiedMatrix","") end)
    pcall(function() self:SetConfig("InstaKill.VerifiedBackend","") end)
    return self:SetConfig("InstaKill.VerificationStatus","UNTESTED")
end

IK.token=(IK.token or 0)+1
local token=IK.token
task.spawn(function()
    while not RAVYN._destroyed and IK.token==token do
        local now=os.clock()
        local ok,err=pcall(function() engageStep(now); sessionStep(now); armStep(now); creditStep(now) end)
        if not ok then RAVYN.Logger:log("ERROR","INSTAKILL_TICK",{error=tostring(err)}); release("ERROR") end
        task.wait((IK.session or #IK.pending>0) and .05 or .15)
    end
    release("DESTROYED")
end)
local baseStop=RAVYN.Stop
function RAVYN:Stop() release("STOP"); IK.engaged=nil; return baseStop(self) end
local baseDestroy=RAVYN.Destroy
function RAVYN:Destroy() IK.token=IK.token+1; release("DESTROY"); IK.pending={}; V.queue={}; return baseDestroy(self) end
if LP then table.insert(RAVYN._connections,LP.CharacterAdded:Connect(function() release("RESPAWN"); IK.engaged=nil end)) end
CTX["InstaKill122"]=IK
RAVYN.Logger:log("INFO","INSTAKILL_ADAPTER_V122_READY")
return true]==========]); if not ok then return end end

do local ok=runChunk("UI384_Core.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local Brain=CTX["Brain"]
local result=CTX["result"]
-- RAVYN UI v3.8.4 · state-aware premium console.
-- Presentation only: reads a normalized UIState snapshot, calls public RAVYN:* setters. Never drives automation.
if type(RAVYN.Config.UI.ReducedMotion)~="boolean" then RAVYN.Config.UI.ReducedMotion=false end
RAVYN.Config.UI.DeveloperMode=false -- DIRECT release: dev/research stays hidden unless deliberately re-enabled in Settings
local U={pages={},navButtons={},badges={},refreshers={},toggles={},C=nil,S=nil,hidden=false}
local TweenService=game:GetService("TweenService")
local UIS=game:GetService("UserInputService")

U.C={
    bg=Color3.fromRGB(11,11,14), panel=Color3.fromRGB(17,17,21), card=Color3.fromRGB(23,23,28), raised=Color3.fromRGB(32,32,39),
    line=Color3.fromRGB(44,44,53), text=Color3.fromRGB(240,240,245), sub=Color3.fromRGB(168,168,180), faint=Color3.fromRGB(104,104,116),
    green=Color3.fromRGB(74,206,132), gold=Color3.fromRGB(228,188,76), cyan=Color3.fromRGB(86,196,236), purple=Color3.fromRGB(162,128,250),
    orange=Color3.fromRGB(244,158,72), red=Color3.fromRGB(238,92,92), gray=Color3.fromRGB(118,118,130),
    goldDim=Color3.fromRGB(62,52,24), redDim=Color3.fromRGB(58,20,22), greenDim=Color3.fromRGB(22,52,36), cyanDim=Color3.fromRGB(20,46,58), purpleDim=Color3.fromRGB(42,32,66), orangeDim=Color3.fromRGB(64,40,18),
}
local C=U.C
U.dim={[C.green]=C.greenDim,[C.gold]=C.goldDim,[C.cyan]=C.cyanDim,[C.purple]=C.purpleDim,[C.orange]=C.orangeDim,[C.red]=C.redDim}
function U.dimOf(c) return U.dim[c] or C.raised end
U.F={bold=Enum.Font.GothamBold,semi=Enum.Font.GothamMedium,body=Enum.Font.Gotham,mono=Enum.Font.Code}

-- ---------------- primitives ----------------
U.FontScale=1.34
function U.n(class,parent,props)
    local x=Instance.new(class)
    for k,v in pairs(props or {}) do x[k]=v end
    if (class=="TextLabel" or class=="TextButton" or class=="TextBox") and props and type(props.TextSize)=="number" then
        x.TextSize=math.floor(props.TextSize*(U.FontScale or 1)+.5)
    end
    x.Parent=parent; return x
end
function U.round(x,r) U.n("UICorner",x,{CornerRadius=UDim.new(0,r or 12)}) end
function U.stroke(x,c,t,tr) return U.n("UIStroke",x,{Color=c or C.line,Thickness=t or 1,Transparency=tr or .25,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
function U.pad(x,l,r,t,b) U.n("UIPadding",x,{PaddingLeft=UDim.new(0,l or 0),PaddingRight=UDim.new(0,r or l or 0),PaddingTop=UDim.new(0,t or 0),PaddingBottom=UDim.new(0,b or t or 0)}) end
function U.list(x,gap,dir) return U.n("UIListLayout",x,{Padding=UDim.new(0,gap or 8),SortOrder=Enum.SortOrder.LayoutOrder,FillDirection=dir or Enum.FillDirection.Vertical}) end
function U.label(parent,text,size,color,font,props)
    local l=U.n("TextLabel",parent,{BackgroundTransparency=1,Text=text or "",TextSize=size or 12,TextColor3=color or C.text,Font=font or U.F.body,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextWrapped=true,Size=UDim2.new(1,0,0,(size or 12)+8)})
    for k,v in pairs(props or {}) do l[k]=v end
    return l
end

-- ---------------- centralized animation ----------------
local running=setmetatable({},{__mode="k"})
local lastVal=setmetatable({},{__mode="k"})
local targets=setmetatable({},{__mode="k"})
function U.anim(obj,dur,props,style,dir)
    if not obj or not obj.Parent then return end
    local key=""; local sig=""
    for k,v in pairs(props) do key=key..k.."|"; sig=sig..k.."="..tostring(v).."|" end
    running[obj]=running[obj] or {}; targets[obj]=targets[obj] or {}
    local prev=running[obj][key]
    -- already animating toward this exact target: do nothing (no restart storm)
    if prev and targets[obj][key]==sig and prev.PlaybackState==Enum.PlaybackState.Playing then return prev end
    -- Cancel() leaves the property at its CURRENT value; the new tween starts from there (no reset)
    if prev then prev:Cancel() end
    targets[obj][key]=sig
    if RAVYN.Config.UI.ReducedMotion or U.hidden then for k,v in pairs(props) do obj[k]=v end; running[obj][key]=nil; return end
    local t=TweenService:Create(obj,TweenInfo.new(dur or .2,style or Enum.EasingStyle.Quint,dir or Enum.EasingDirection.Out),props)
    running[obj][key]=t; t:Play(); return t
end
-- change-only setters: nothing happens (and nothing animates) if the value did not change
function U.setText(l,t) t=tostring(t or ""); if l.Text~=t then l.Text=t end end
function U.setColor(obj,prop,color,dur)
    lastVal[obj]=lastVal[obj] or {}
    if lastVal[obj][prop]==color then return end
    lastVal[obj][prop]=color
    U.anim(obj,dur or .18,{[prop]=color})
end
function U.setSize(obj,size,dur)
    lastVal[obj]=lastVal[obj] or {}
    local k=tostring(size); if lastVal[obj].Size==k then return end
    lastVal[obj].Size=k; U.anim(obj,dur or .24,{Size=size})
end
-- DIRECT v1 motion language: springy hover/press feedback with no per-frame animation loops.
function U.pressable(obj,opts)
    if not obj or not obj:IsA("GuiButton") then return obj end
    opts=opts or {}
    local sc=obj:FindFirstChild("RAVYN_MotionScale") or U.n("UIScale",obj,{Name="RAVYN_MotionScale",Scale=1})
    local hoverScale=opts.hoverScale or 1.018
    local pressScale=opts.pressScale or .965
    local enterColor=opts.enterColor
    local leaveColor=opts.leaveColor
    table.insert(RAVYN._connections,obj.MouseEnter:Connect(function()
        U.anim(sc,.18,{Scale=hoverScale},Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
        if enterColor then U.anim(obj,.14,{BackgroundColor3=enterColor}) end
    end))
    table.insert(RAVYN._connections,obj.MouseLeave:Connect(function()
        U.anim(sc,.22,{Scale=1},Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
        if leaveColor then U.anim(obj,.18,{BackgroundColor3=leaveColor}) end
    end))
    table.insert(RAVYN._connections,obj.MouseButton1Down:Connect(function()
        U.anim(sc,.085,{Scale=pressScale},Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
    end))
    table.insert(RAVYN._connections,obj.MouseButton1Up:Connect(function()
        U.anim(sc,.26,{Scale=hoverScale},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
    end))
    return obj
end
function U.reveal(obj,offset)
    if not obj then return end
    local sc=obj:FindFirstChild("RAVYN_PageScale") or U.n("UIScale",obj,{Name="RAVYN_PageScale",Scale=.985})
    sc.Scale=.985; obj.Position=UDim2.fromOffset(offset or 18,0)
    U.anim(obj,.28,{Position=UDim2.fromOffset(0,0)},Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
    U.anim(sc,.34,{Scale=1},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
end

-- ---------------- human-readable diagnostics ----------------
U.MSG={
    NO_VISIBLE_SKILL_KEYS={"Skills not ready","No visible hotbar keys were detected.","orange"},
    ["SKILLS_HIDDEN · EQUIP_BINDING_UNRESOLVED"]={"Equip required","Skills were seen before but the hotbar is hidden. No verified equip input exists.","orange"},
    ["OUT_OF_RANGE · TRAVELING"]={"Traveling","Skills resume when Combat Hover locks on.","cyan"},
    OUT_OF_RANGE={"Out of range","Target is outside skill range.","orange"},
    DEFENSE_ACTIVE={"Defending","A dodge or guard is running; combo resumes after.","gold"},
    ["EMERGENCY · COMBAT PAUSED"]={"Emergency","Critical health: survival overrides combo.","red"},
    COMBO_WAIT_M1={"Building combo","Waiting for M1 chain before the next skill.","cyan"},
    INPUT_UNAVAILABLE={"Input unavailable","The executor rejected the key/mouse input.","red"},
    SKILL_ERROR={"Skill error","The skill call raised an error; see Diagnostics.","red"},
    OK={"Firing","Last skill input was sent.","green"},
    IDLE={"Idle","No combat yet.","gray"},
    QUEST_TARGET_UNRESOLVED={"Quest target unknown","RAVYN is looking for runtime evidence such as a quest marker. Random kill learning is disabled unless explicitly enabled.","gold"},
    RESEARCH_REQUIRED={"Research required","This system's runtime behaviour is not mapped yet. Record it in Research → Learn action first.","orange"},
    QUEST_SOURCE_NOT_FOUND={"No quest source","No Crow, Muzan or quest prompt is streamed or remembered yet.","orange"},
    QUEST_SOURCE_OUT_OF_STREAM={"Source out of stream","Traveling to the last observed position.","cyan"},
    QUEST_ACCEPT_UNVERIFIED={"Accept not verified","The quest text did not change after interaction. Backing off.","orange"},
    QUEST_TURNIN_UNVERIFIED={"Turn-in not verified","The quest did not clear after interaction. Backing off.","orange"},
    QUEST_PROGRESS_STALLED={"Progress stalled","No progress change for a while.","orange"},
    FIREPROXIMITYPROMPT_UNAVAILABLE={"Interaction unavailable","This executor has no fireproximityprompt.","red"},
    OBJECTIVE_UNKNOWN_OBSERVING={"Objective unknown","Observing only; no action is invented.","gray"},
    CHEST_BINDING_UNRESOLVED={"Chest action unavailable","No verified interaction path for chests.","red"},
    CHEST_OPEN_UNVERIFIED={"Chest not verified","The chest prompt stayed active after opening.","orange"},
    LOOT_BINDING_UNRESOLVED={"Loot action unavailable","No verified interaction path for drops.","red"},
    LOOT_TIMEOUT={"Loot timed out","Session ended before all drops were verified.","orange"},
    NO_DROPS_DETECTED={"No drops","Nothing new appeared near the kill.","gray"},
    HOTBAR_KEYS_UNRESOLVED={"Hotbar keys unresolved","No visible skill slot exposes a key label. Skill attempts are throttled.","orange"},
    SKILL_HOTBAR_NOT_READY={"Hotbar not ready","Skills were visible earlier: hotbar hidden, loadout changed, weapon unequipped or respawn. No equip input is verified.","orange"},
    SKILL_INPUT_SENT_UNVERIFIED={"Skill not confirmed","The key was sent but no GUI, animation or damage evidence followed.","orange"},
    SKILL_BACKOFF={"Skill backing off","Repeated unverified casts; that key rests briefly.","gold"},
    INPUT_SENT={"Verifying skill","Input sent, waiting for evidence.","cyan"},
    NO_READY_SKILL={"Skills cooling down","Every discovered skill is on learned cooldown or backoff.","cyan"},
    OUT_OF_LEARNED_RANGE={"Outside learned range","Target is beyond the range where these skills were verified.","orange"},
    CHEST_NOT_FOUND={"Chest not found","No object matching the boss chest identity appeared nearby. A loot probe was captured.","orange"},
    CHEST_INTERACTION_UNRESOLVED={"Chest interaction unknown","The chest was found but exposes no prompt, click or touch affordance.","red"},
    FIRECLICKDETECTOR_UNAVAILABLE={"Click interaction unavailable","This executor has no fireclickdetector.","red"},
    QUEST_TARGET_NEEDS_EVIDENCE={"Quest target needs evidence","No marker or learned mapping identifies the target. RAVYN waits instead of farming random mobs. Record it with Research → Learn action.","gold"},
    QUEST_SOURCE_MISMATCH={"Wrong prompt interacted","A different quest prompt than the chosen source was triggered.","orange"},
    LOOT_PREEMPTED_EXPIRED={"Loot abandoned","Higher-priority work held the loot session too long.","orange"},
    ADAPTIVE_INTEL_UNAVAILABLE={"Quest parser missing","AdaptiveIntel did not install.","red"},
}
function U.explain(code)
    if not code or code=="" then return nil end
    local m=U.MSG[code]
    if not m and type(code)=="string" and string.find(code,"^OBJECTIVE_") then m={"Objective needs binding","This objective type has no verified action yet.","gray"} end
    if not m then return {title=tostring(code),detail="",color=C.orange,code=code} end
    return {title=m[1],detail=m[2],color=C[m[3]] or C.orange,code=code}
end
-- v3.9 Developer Mode: technical UI is registered once at build time and only shown in developer mode.
-- Visibility changes only on the user's toggle (never from telemetry).
U.devItems={}
function U.devOnly(inst) if inst then table.insert(U.devItems,inst); inst.Visible=RAVYN.Config.UI.DeveloperMode==true end; return inst end
function U.devRow(valueLabel) return U.devOnly(valueLabel and valueLabel.Parent) end
function U.applyDevMode()
    local on=RAVYN.Config.UI.DeveloperMode==true
    for _,x in ipairs(U.devItems) do if x and x.Parent then x.Visible=on end end
    if U.onDevModeChanged then pcall(U.onDevModeChanged,on) end
end
-- plain wording for capability states in simple mode
function U.plainCap(s) return (s=="VERIFIED" and "Ready") or (s=="RESEARCH_REQUIRED" and "Needs research") or (s=="UNRESOLVED" and "Not available yet") or "Being tested" end
-- capability colours (single vocabulary from GameKnowledge)
function U.capColor(s)
    return (s=="VERIFIED" and C.green) or (s=="PARTIAL" and C.orange) or (s=="AWAITING_LIVE" and C.cyan)
        or (s=="RESEARCH_REQUIRED" and C.purple) or (s=="DISABLED" and C.gray) or C.faint
end
function U.capRow(parent,key)
    return U.kv(parent,(RAVYN.GameKnowledge and RAVYN.GameKnowledge.capabilities[key] and RAVYN.GameKnowledge.capabilities[key].title) or key,function()
        local GK=RAVYN.GameKnowledge; local c=GK and GK.capability(key)
        if not c then return "UNRESOLVED",C.faint end
        return GK.statusLabel(c.status),U.capColor(c.status)
    end)
end
CTX["UI384"]=U
return true]==========]); if not ok then return end end
do local ok=runChunk("UI384_Widgets.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local Brain=CTX["Brain"]
local U=CTX["UI384"]
local C=U.C
-- ================= normalized UI state =================
local errState={last=nil,at=-math.huge}
function U.buildState()
    local now=os.clock(); local S={now=now}
    local cfg=RAVYN.Config
    S.version=tostring(RAVYN.Version); S.fsm=RAVYN.FSM and RAVYN.FSM.state or "STOPPED"
    S.autoplay=cfg.Intelligence and cfg.Intelligence.AutoPlay==true
    local JS=RAVYN.JobScheduler or {}
    S.job=JS.job or "IDLE"; S.overlay=JS.overlay; S.jobLabel=JS.label or ""; S.priority=JS.priority or 0; S.bosses=JS.bossDiag or {}; S.eligibleBosses=JS.eligibleBossCount or 0
    local MO=RAVYN.MoveOwner or {}; local NC=RAVYN.NoclipController or {}
    S.owner=MO.current or "IDLE"; S.moveReason=MO.reason or ""; S.travelMode=MO.travelMode or "—"; S.teleports=MO.teleports or 0; S.tweens=MO.tweens or 0; S.noclip=NC.active==true
    local p=(RAVYN.Features and RAVYN.Features.snapshot or {}).player or {}
    S.hp=p.health; S.hpMax=p.maxHealth; S.dead=p.dead==true
    S.hpPct=(p.health and p.maxHealth and p.maxHealth>0) and math.clamp(p.health/p.maxHealth*100,0,100) or nil
    S.risk=Brain.riskScore or 0; S.dps=Brain.damagePerSecond or 0; S.emergency=Brain.forceEvade and Brain.emergency384
    local t=LiveAction.target
    if t then
        S.target={name=tostring(t.name),boss=t.isBoss==true or t.classification=="BOSS",dist=(MO.liveDistance and S.owner~="IDLE") and MO.liveDistance or t.distance,
            hpPct=(t.health and t.maxHealth and t.maxHealth>0) and math.clamp(t.health/t.maxHealth*100,0,100) or nil}
    end
    local M=RAVYN.CombatMobility or {}
    S.hover=M.hoverState or "STANDBY"; S.m1=M.m1Sent or 0; S.skills=M.skillSent or 0; S.skillAttempts=M.skillAttempts or 0; S.skillFail=M.skillFailReason or "IDLE"
    S.lastSkill=M.lastSkillKey; S.lastSkillAt=M.lastSkillAt or 0; S.combo=M.comboStage or 0; S.discovered=M.skillsDiscovered or 0; S.mitigation=M.mitigation or {}
    S.verified=M.skillVerified or 0; S.combatState=M.combatState or "IDLE"; S.nextAction=M.nextAction or "—"; S.recovery=M.recoveryState or "STANDBY"
    S.skillKeys=M.skillKeys or {}; S.skillStats=M.skill or {}; S.keySources=M.keySources or ""; S.readiness=M.readiness
    local lastStat=M.lastSkillKey and M.skill and M.skill[M.lastSkillKey]
    S.lastSkillVerdict=lastStat and ((lastStat.lastVerifiedAt==M.lastSkillAt and "VERIFIED") or (M.pending and M.pending.key==M.lastSkillKey and "CASTING") or "UNVERIFIED") or nil
    local E=RAVYN.CombatEvolution
    S.defense=(E and (E.dodgeUntil or 0)>now and "DODGING") or (E and E.guardDown and "GUARDING") or "READY"
    local QB=RAVYN.QuestBrain or {}; local qcfg=cfg.QuestBrain or {}
    S.questEnabled=(qcfg.AutoQuest or qcfg.AutoCrow or qcfg.AutoMuzan) and true or false
    local src=QB.sources and QB.sources[QB.activeSourceId or QB.targetSourceId or ""]
    local A=RAVYN.AdaptiveIntel; local q=A and A.quest or {}
    S.quest={state=QB.state or "IDLE",phase=QB.phase or "IDLE",nav=QB.navigating==true,source=(src and src.type) or (q.source~="UNKNOWN" and q.source) or "—",
        sourceName=src and src.name,objective=QB.objective or q.objectiveType or "NONE",target=QB.targetName or q.targetName,confidence=QB.confidence or "UNKNOWN",
        progress=q.progress,required=q.required,fail=QB.failReason,accepted=QB.accepted or 0,completed=QB.completed or 0,level=QB.lastLevel,stalled=QB.stalled}
    local LC=RAVYN.LootController or {}
    S.loot={active=LC.active==true,state=LC.state or "IDLE",detected=LC.detected or 0,collected=LC.collected or 0,unverified=LC.unverified or 0,last=LC.lastResult or "—",fail=LC.failReason,
        attempted=LC.attempted or 0,remaining=LC.remaining or 0,boss=LC.bossName,chestExpected=LC.expectedChest,chest=LC.chestState or "—",chestPath=LC.chestPath,chestVia=LC.chestInteraction,hasProbe=LC.probe~=nil}
    local APx=RAVYN.AutoPlay384 or {}; local Hx=APx.handoff or {}; local ts=APx.sessionInfo and APx.sessionInfo()
    S.handoff={listener=Hx.listener or "NONE",session=ts and ts.token or Hx.session,sessionName=ts and ts.name,sessionChest=ts and ts.chest,
        deathBy=Hx.deathBy,handled=Hx.handled==true,context=Hx.context or "NONE",startCalled=Hx.startCalled==true,startResult=Hx.startResult,
        lastBoss=Hx.lastBoss,pending=APx.deathPending==true,lost=APx.lostTargets or 0,source=ts and ts.source}
    local err=RAVYN.Features and RAVYN.Features.lastError
    if err~=errState.last then errState.last=err; if err then errState.at=now end end
    S.errorRecent=err~=nil and now-errState.at<6; S.error=err
    -- v3.9 simple language (no engineering terms for normal users)
    local GO=RAVYN.GoState; S.dev=RAVYN.Config.UI.DeveloperMode==true
    S.go={active=GO and GO.active or false,paused=GO and GO.paused or false,goal=(GO and GO.goal) or (RAVYN.Config.Go and RAVYN.Config.Go.Goal) or "AUTO_PROGRESS",
        state=GO and GO.state() or "READY"}
    S.goalTitle=(GO and GO.goals[S.go.goal] and GO.goals[S.go.goal].title) or "Auto Progress"
    if now-(U.levelAt or -math.huge)>2 then
        U.levelAt=now; local RA=RAVYN.ReadAdapter; local l=RA and RA:getLevel(); U.levelCache=(l and l.ok) and l.value or nil
    end
    S.level=U.levelCache
    local tName=S.target and S.target.name
    local plain
    if S.fsm~="RUNNING" then plain=(S.go.paused or S.fsm=="PAUSED") and "Paused" or "Ready"
    elseif S.overlay=="EMERGENCY" or (S.recovery and S.recovery~="STANDBY") then plain="Recovering"
    elseif S.overlay=="DEFENSE" then plain="Defending"
    elseif S.loot.active then plain="Looting"
    elseif S.quest.nav and S.quest.phase=="TURN_IN" then plain="Turning in quest"
    elseif S.quest.nav and S.quest.phase=="INVESTIGATE" then plain="Finding quest target"
    elseif S.quest.nav then plain="Going to quest"
    elseif S.owner=="TRAVEL" and tName then plain="Moving to "..tName
    elseif tName then plain="Fighting "..tName
    elseif S.quest.fail=="QUEST_TARGET_NEEDS_EVIDENCE" then plain="Needs research"
    else plain="Finding target" end
    S.plain=plain
    local qActive=S.quest.phase=="ACTIVE" or S.quest.phase=="INVESTIGATE"
    if qActive and S.quest.target then S.headline="Quest · Defeat "..S.quest.target
    elseif qActive then S.headline="Quest · "..tostring(S.quest.objective)
    elseif S.target and S.target.boss then S.headline="Boss · "..tName
    elseif S.loot.active and S.loot.boss then S.headline="Loot · "..S.loot.boss
    else S.headline=S.goalTitle end
    if S.loot.active then S.next=S.loot.chestExpected and "Open chest → Collect → Continue" or "Collect → Continue"
    elseif qActive and S.quest.progress and S.quest.required and S.quest.progress>=S.quest.required then S.next="Turn in → Next quest"
    elseif qActive then S.next="Fight → Loot → Continue quest"
    elseif S.target and S.target.boss then S.next="Defeat → Chest → Next boss"
    elseif S.target then S.next="Defeat → Next target"
    elseif S.owner=="TRAVEL" then S.next="Arrive → Fight"
    else S.next="Looking for the next objective" end
    if S.quest.progress then S.progressText=string.format("%d / %d",S.quest.progress,S.quest.required or 0)
    elseif S.loot.active then S.progressText=string.format("Items %d / %d",S.loot.collected,S.loot.detected)
    elseif S.target and S.target.hpPct then S.progressText=string.format("Target %d%%",math.floor(S.target.hpPct+.5))
    else S.progressText="—" end
    -- semantic debounce (display only): brief flips such as COMBAT_HOVER↔DEFENSE on a dodge or
    -- M1_CHAIN↔SKILL_CAST must not repaint chips; recovery/emergency always shows immediately
    local urgentCombat=S.combatState=="RECOVERY" or S.combatState=="IDLE"
    S.combatState=U.stable("combat",S.combatState,now,.6,urgentCombat)
    S.owner=U.stable("owner",S.owner,now,.45,S.owner=="RECOVERY" or S.owner=="IDLE")
    -- global master state
    local g,gc
    if S.fsm=="PAUSED" then g,gc="PAUSED",C.orange
    elseif S.fsm~="RUNNING" then g,gc=(S.autoplay and "STARTING" or "READY"),C.gray
    elseif S.errorRecent then g,gc="ERROR",C.red
    elseif S.overlay=="EMERGENCY" then g,gc=(S.recovery~="STANDBY" and S.recovery or "RECOVERING"),C.red
    elseif S.overlay=="DEFENSE" then g,gc="DEFENDING",C.gold
    elseif S.loot.active then g,gc="LOOTING",C.gold
    elseif S.quest.nav then g,gc="QUESTING",C.purple
    elseif S.owner=="TRAVEL" then g,gc="TRAVELING",C.cyan
    elseif S.owner=="COMBAT_HOVER" or (S.target and S.job~="IDLE") then g,gc="FIGHTING",C.green
    elseif S.job=="IDLE" then g,gc=(S.autoplay and "THINKING" or "WAITING"),C.sub
    else g,gc="ACTIVE",C.green end
    local urgentG=(g=="ERROR" or g=="RECOVERING" or g=="PAUSED" or g=="READY" or string.find(g,"RECOVERY",1,true)~=nil)
    local shownG=U.stable("global",g,now,.5,urgentG)
    if shownG~=g then g=shownG; gc=(g=="FIGHTING" and C.green) or (g=="TRAVELING" and C.cyan) or (g=="DEFENDING" and C.gold) or (g=="LOOTING" and C.gold) or (g=="QUESTING" and C.purple) or C.sub end
    S.global=(S.autoplay and "AUTO PLAY · " or "MANUAL · ")..g; S.globalColor=gc; S.activity=g
    -- pipeline (derived from the active scheduler job, not hard-coded to Crow)
    local questFlow=S.autoplay and S.questEnabled and S.quest.phase~="IDLE"
    if questFlow then
        S.stages={"QUEST","TRAVEL","COMBAT","LOOT","TURN IN"}
        local ph=S.quest.phase
        if S.loot.active then S.stage="LOOT"
        elseif ph=="TURN_IN" then S.stage="TURN IN"
        elseif ph=="ACQUIRE" then S.stage=(S.owner=="TRAVEL") and "TRAVEL" or "QUEST"
        elseif S.owner=="TRAVEL" then S.stage="TRAVEL"
        elseif S.target then S.stage="COMBAT" else S.stage="QUEST" end
    else
        S.stages={"SCAN","TRAVEL","COMBAT","LOOT"}
        if S.loot.active then S.stage="LOOT" elseif S.owner=="TRAVEL" then S.stage="TRAVEL"
        elseif S.owner=="COMBAT_HOVER" or S.owner=="DEFENSE" or S.owner=="RECOVERY" or S.target then S.stage="COMBAT" else S.stage="SCAN" end
    end
    return S
end
function U.ownerColor(o) return (o=="TRAVEL" and C.cyan) or (o=="COMBAT_HOVER" and C.green) or (o=="DEFENSE" and C.gold) or (o=="RECOVERY" and C.red) or C.gray end
function U.hpColor(p) if not p then return C.gray end; return (p<=25 and C.red) or (p<=50 and C.orange) or C.green end
function U.fmtDist(d) if not d or d~=d or d==math.huge then return "—" end; return string.format("%.0f studs",d) end
-- v3.8.4.3: refreshers are scoped to the page that built them; only the visible page (plus global chrome) updates.
U.pageRefreshers={}
function U.addRefresh(fn)
    local p=U.buildingPage
    if p then U.pageRefreshers[p]=U.pageRefreshers[p] or {}; table.insert(U.pageRefreshers[p],fn) else table.insert(U.refreshers,fn) end
end
local function runList(list,S)
    for _,fn in ipairs(list or {}) do local ok,err=pcall(fn,S); if not ok then RAVYN.Logger:log("WARN","UI_REFRESH",{error=tostring(err)}) end end
end
function U.runGlobal(S) runList(U.refreshers,S) end
function U.runPage(name) if U.S and name then runList(U.pageRefreshers[name],U.S) end end
-- semantic debounce: a displayed state changes only after it held for minHold seconds (urgent values pass at once)
local stableMem={}
function U.stable(key,value,now,minHold,urgent)
    local m=stableMem[key]
    if not m then m={shown=value,cand=value,since=now}; stableMem[key]=m; return value end
    if value==m.shown then m.cand=value; return m.shown end
    if urgent then m.shown=value; m.cand=value; return value end
    if value~=m.cand then m.cand=value; m.since=now end
    if now-m.since>=minHold then m.shown=value end
    return m.shown
end

-- ================= widgets =================
-- Card with optional collapse + warning badge. Returns card, body.
function U.card(parent,title,subtitle,opts)
    opts=opts or {}
    local card=U.n("Frame",parent,{Size=UDim2.new(1,-4,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C.panel,BorderSizePixel=0,LayoutOrder=opts.order or 0})
    U.round(card,14); U.stroke(card,C.line,1,.35); U.pad(card,16,16,14,14); U.list(card,8)
    local head=U.n("TextButton",card,{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,Text="",AutoButtonColor=false,LayoutOrder=0})
    local tl=U.label(head,title,14,C.text,U.F.bold,{Size=UDim2.new(1,-40,1,0)})
    local badge=U.n("Frame",head,{Size=UDim2.fromOffset(8,8),Position=UDim2.new(1,-26,.5,-4),BackgroundColor3=C.orange,Visible=false,BorderSizePixel=0}); U.round(badge,4)
    local chev=U.label(head,opts.collapsible and "▾" or "",13,C.faint,U.F.bold,{Size=UDim2.fromOffset(14,20),Position=UDim2.new(1,-14,0,0),TextXAlignment=Enum.TextXAlignment.Right})
    if subtitle and subtitle~="" then U.label(card,subtitle,11,C.sub,U.F.body,{AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0),LayoutOrder=1}) end
    local body=U.n("Frame",card,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=2}); U.list(body,8)
    if opts.collapsible then
        local open=not opts.collapsed; body.Visible=open; chev.Text=open and "▾" or "▸"
        table.insert(RAVYN._connections,head.Activated:Connect(function() open=not open; body.Visible=open; chev.Text=open and "▾" or "▸" end))
    end
    if opts.warn then U.addRefresh(function(S) local w=opts.warn(S); badge.Visible=w~=nil; if w then badge.BackgroundColor3=w end end) end
    card:SetAttribute("title",title); tl.Name="Title"
    return card,body
end
-- key/value row with live value + semantic color
function U.kv(parent,key,fn,opts)
    opts=opts or {}
    local row=U.n("Frame",parent,{Size=UDim2.new(1,0,0,opts.h or 22),BackgroundTransparency=1})
    U.label(row,key,12,C.sub,U.F.semi,{Size=UDim2.new(.36,0,1,0)})
    local v=U.label(row,"—",opts.size or 13,C.text,opts.mono and U.F.mono or U.F.bold,{Size=UDim2.new(.64,0,1,0),Position=UDim2.new(.36,0,0,0),TextXAlignment=Enum.TextXAlignment.Right,TextTruncate=Enum.TextTruncate.AtEnd,TextWrapped=false})
    U.addRefresh(function(S) local text,color=fn(S); U.setText(v,text); if color then U.setColor(v,"TextColor3",color) end end)
    return v
end
-- animated progress bar
function U.bar(parent,fn,h)
    local track=U.n("Frame",parent,{Size=UDim2.new(1,0,0,h or 6),BackgroundColor3=C.raised,BorderSizePixel=0}); U.round(track,3)
    local fill=U.n("Frame",track,{Size=UDim2.new(0,0,1,0),BackgroundColor3=C.green,BorderSizePixel=0}); U.round(fill,3)
    local lastF=nil
    U.addRefresh(function(S)
        local f,color=fn(S); f=math.floor(math.clamp(tonumber(f) or 0,0,1)*200+.5)/200 -- 0.5% steps
        if f~=lastF then lastF=f; fill.Size=UDim2.new(f,0,1,0) end -- metric: direct set, no tween
        if color then U.setColor(fill,"BackgroundColor3",color) end
    end)
    return track
end
-- status chip
function U.chip(parent,fn,w)
    local chip=U.n("Frame",parent,{Size=UDim2.fromOffset(w or 120,22),BackgroundColor3=C.raised,BorderSizePixel=0}); U.round(chip,11)
    local l=U.label(chip,"—",10,C.sub,U.F.bold,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextWrapped=false})
    U.addRefresh(function(S) local text,color=fn(S); U.setText(l,text); color=color or C.sub; U.setColor(l,"TextColor3",color); U.setColor(chip,"BackgroundColor3",U.dimOf(color),.22) end)
    return chip,l
end
-- toast stack with dedupe
U.toastHost=nil; local recentToasts={}
function U.toast(text,kind,long)
    if not U.toastHost then return end
    local now=os.clock(); text=tostring(text)
    if recentToasts[text] and now-recentToasts[text]<3 then return end
    recentToasts[text]=now
    local color=(kind=="success" and C.green) or (kind=="warn" and C.orange) or (kind=="error" and C.red) or C.cyan
    local kids=0; for _,x in ipairs(U.toastHost:GetChildren()) do if x:IsA("CanvasGroup") then kids=kids+1 end end
    if kids>=3 then for _,x in ipairs(U.toastHost:GetChildren()) do if x:IsA("CanvasGroup") then x:Destroy(); break end end end
    local t=U.n("CanvasGroup",U.toastHost,{Size=UDim2.new(1,0,0,44),BackgroundColor3=C.raised,GroupTransparency=1,BorderSizePixel=0,LayoutOrder=math.floor(now*100)})
    U.round(t,14); U.stroke(t,color,1,.55)
    local ts=U.n("UIScale",t,{Scale=.94})
    U.n("Frame",t,{Size=UDim2.new(0,3,1,-14),Position=UDim2.fromOffset(8,7),BackgroundColor3=color,BorderSizePixel=0})
    U.label(t,text,12,C.text,U.F.semi,{Size=UDim2.new(1,-28,1,0),Position=UDim2.fromOffset(20,0),TextTruncate=Enum.TextTruncate.AtEnd,TextWrapped=false})
    U.anim(t,.2,{GroupTransparency=0}); U.anim(ts,.32,{Scale=1},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
    task.delay(long and 5 or 2.8,function() if t.Parent then U.anim(t,.25,{GroupTransparency=1}); U.anim(ts,.2,{Scale=.96}); task.delay(.26,function() if t.Parent then t:Destroy() end end) end end)
end
function U.report(r,okText)
    if type(r)~="table" then U.toast(okText or "Done","success"); return end
    local e=(not r.ok) and U.explain(r.code) or nil
    if r.ok then U.toast(okText or tostring(r.code or "OK"),"success") else U.toast(e and e.title or tostring(r.code),"warn") end
end
-- toggle with state chip + dependency dimming + tooltip
function U.toggle(parent,spec)
    local row=U.n("Frame",parent,{Size=UDim2.new(1,0,0,spec.desc and 46 or 30),BackgroundTransparency=1})
    local title=U.label(row,spec.label,13,C.text,U.F.semi,{Size=UDim2.new(1,-150,0,18),Position=UDim2.fromOffset(0,spec.desc and 3 or 6),TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd})
    local desc=spec.desc and U.label(row,spec.desc,11,C.sub,U.F.body,{Size=UDim2.new(1,-150,0,16),Position=UDim2.fromOffset(0,24),TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd}) or nil
    local chip,chipL
    if spec.status then
        chip=U.n("Frame",row,{Size=UDim2.fromOffset(82,20),Position=UDim2.new(1,-138,.5,-10),BackgroundColor3=C.raised,BorderSizePixel=0}); U.round(chip,10)
        chipL=U.label(chip,"",9,C.sub,U.F.bold,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextWrapped=false})
    end
    local track=U.n("TextButton",row,{Size=UDim2.fromOffset(46,26),Position=UDim2.new(1,-46,.5,-13),BackgroundColor3=C.raised,Text="",AutoButtonColor=false,BorderSizePixel=0}); U.round(track,13)
    local knob=U.n("Frame",track,{Size=UDim2.fromOffset(20,20),Position=UDim2.fromOffset(3,3),BackgroundColor3=C.text,BorderSizePixel=0}); U.round(knob,10)
    local glow=U.stroke(track,C.gold,2,1)
    local lastOn=nil; local lastEnabled=nil
    local function refresh(S)
        local on=spec.get()==true; local enabled=(not spec.dep) or spec.dep()==true
        if on~=lastOn then
            U.anim(knob,.22,{Position=on and UDim2.fromOffset(23,3) or UDim2.fromOffset(3,3)},Enum.EasingStyle.Back)
            U.setColor(track,"BackgroundColor3",on and C.gold or C.raised,.2)
            if lastOn~=nil and on then glow.Transparency=.2; U.anim(glow,.45,{Transparency=1}) end
            lastOn=on
        end
        if enabled~=lastEnabled then
            U.setColor(title,"TextColor3",enabled and C.text or C.faint); if desc then U.setColor(desc,"TextColor3",enabled and C.sub or C.faint) end
            U.setColor(knob,"BackgroundColor3",enabled and C.text or C.gray); lastEnabled=enabled
        end
        if chip and S then local text,color=spec.status(S,on); color=color or C.sub; U.setText(chipL,text or ""); U.setColor(chipL,"TextColor3",color); U.setColor(chip,"BackgroundColor3",U.dimOf(color)) end
    end
    table.insert(RAVYN._connections,track.Activated:Connect(function()
        if spec.dep and spec.dep()~=true then U.toast(spec.depText or "Enable the parent option first","warn"); return end
        local ok,r=pcall(spec.set,not (spec.get()==true))
        if not ok then U.toast(tostring(r),"error") else U.report(r,spec.label..((spec.get()==true) and " on" or " off")) end
        refresh(U.S)
    end))
    if spec.tip then
        table.insert(RAVYN._connections,track.MouseEnter:Connect(function() U.showTip(spec.tip) end))
        table.insert(RAVYN._connections,track.MouseLeave:Connect(function() U.showTip(nil) end))
    end
    U.addRefresh(refresh); refresh(nil)
    return row
end
-- segmented control with sliding selection indicator
function U.segment(parent,items,get,set,spec)
    spec=spec or {}
    local row=U.n("Frame",parent,{Size=UDim2.new(1,0,0,34),BackgroundColor3=C.card,BorderSizePixel=0}); U.round(row,10)
    local ind=U.n("Frame",row,{Size=UDim2.new(1/#items,-4,1,-6),Position=UDim2.new(0,3,0,3),BackgroundColor3=C.raised,BorderSizePixel=0}); U.round(ind,8); U.stroke(ind,C.line,1,.4)
    local btns={}
    for i,item in ipairs(items) do
        local label=type(item)=="table" and item[1] or item; local value=type(item)=="table" and item[2] or item
        local b=U.n("TextButton",row,{Size=UDim2.new(1/#items,0,1,0),Position=UDim2.new((i-1)/#items,0,0,0),BackgroundTransparency=1,Text=label,TextColor3=C.sub,TextSize=12,Font=U.F.semi,AutoButtonColor=false,ZIndex=2})
        btns[i]={b=b,value=value}
        table.insert(RAVYN._connections,b.Activated:Connect(function()
            if spec.dep and spec.dep()~=true then U.toast(spec.depText or "Unavailable in the current mode","warn"); return end
            local ok,r=pcall(set,value); if not ok then U.toast(tostring(r),"error") else U.report(r,label) end
        end))
    end
    local lastSel=nil; local lastEn=nil
    U.addRefresh(function()
        local cur=get(); local sel=nil
        for i,x in ipairs(btns) do if x.value==cur then sel=i end end
        if sel~=lastSel then
            lastSel=sel; ind.Visible=sel~=nil
            if sel then U.anim(ind,.24,{Position=UDim2.new((sel-1)/#items,3,0,3)}) end
            for i,x in ipairs(btns) do U.setColor(x.b,"TextColor3",i==sel and C.text or C.sub) end
        end
        local en=(not spec.dep) or spec.dep()==true
        if en~=lastEn then lastEn=en; for _,x in ipairs(btns) do x.b.TextTransparency=en and 0 or .55 end end
    end)
    return row
end
function U.button(parent,text,fn,style)
    local col=(style=="accent" and C.goldDim) or (style=="danger" and C.redDim) or C.card
    local tc=(style=="accent" and C.gold) or (style=="danger" and C.red) or C.text
    local b=U.n("TextButton",parent,{Size=UDim2.new(1,0,0,42),BackgroundColor3=col,Text=text,TextColor3=tc,TextSize=13,Font=U.F.semi,AutoButtonColor=false,BorderSizePixel=0}); U.round(b,12)
    local hover=(style=="accent" and Color3.fromRGB(84,70,32)) or (style=="danger" and Color3.fromRGB(84,26,28)) or C.raised
    U.pressable(b,{enterColor=hover,leaveColor=col,hoverScale=1.012,pressScale=.972})
    table.insert(RAVYN._connections,b.Activated:Connect(function()
        local ok,r=pcall(fn,b); if not ok then U.toast(tostring(r),"error") elseif r~=false then U.report(r,text) end
    end))
    return b
end
-- human-readable warning block (title + detail + raw code)
function U.warning(parent,fn)
    local box=U.n("Frame",parent,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C.card,BorderSizePixel=0,Visible=false}); U.round(box,10); U.pad(box,12,12,8,8); U.list(box,2)
    local t=U.label(box,"",12,C.orange,U.F.bold,{Size=UDim2.new(1,0,0,18)})
    local d=U.label(box,"",11,C.sub,U.F.body,{AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0)})
    local c=U.label(box,"",10,C.faint,U.F.mono,{Size=UDim2.new(1,0,0,14)})
    U.addRefresh(function(S)
        local e=U.explain(fn(S)); box.Visible=e~=nil
        if e then U.setText(t,e.title); U.setColor(t,"TextColor3",e.color); U.setText(d,e.detail); U.setText(c,e.code); c.Visible=RAVYN.Config.UI.DeveloperMode==true end
    end)
    return box
end
return true]==========]); if not ok then return end end
do local ok=runChunk("UI384_PagesA.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local result=CTX["result"]
local U=CTX["UI384"]
local C=U.C
local function cfg() return RAVYN.Config end

-- ================= HOME (v3.9 simple core: one goal · one button · one status) =================
function U.buildHome(page)
    local GO=RAVYN.GoState
    -- hero: title, goal, big button
    local hero=U.n("Frame",page,{Size=UDim2.new(1,-4,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C.panel,BorderSizePixel=0,LayoutOrder=1})
    U.round(hero,18); U.stroke(hero,C.gold,1,.68); U.pad(hero,24,24,22,22); U.list(hero,12)
    -- brand row: RAVYN + version on same line
    local brandRow=U.n("Frame",hero,{Size=UDim2.new(1,0,0,22),BackgroundTransparency=1})
    U.label(brandRow,"RAVYN",15,C.gold,U.F.bold,{Size=UDim2.fromOffset(72,22),TextWrapped=false})
    U.label(brandRow,"Direct v1.2.2",11,C.faint,U.F.body,{Size=UDim2.new(1,-80,1,0),Position=UDim2.fromOffset(78,0),TextWrapped=false,TextXAlignment=Enum.TextXAlignment.Left})
    local goalL=U.label(hero,"AUTO PROGRESS",30,C.text,U.F.bold,{Size=UDim2.new(1,0,0,34),TextWrapped=false})
    -- status pill row
    local sRow=U.n("Frame",hero,{Size=UDim2.new(1,0,0,26),BackgroundTransparency=1})
    local sBadge=U.n("Frame",sRow,{Size=UDim2.fromOffset(0,24),AutomaticSize=Enum.AutomaticSize.X,BackgroundColor3=C.raised,BorderSizePixel=0}); U.round(sBadge,12); U.pad(sBadge,10,10,0,0)
    local sDot=U.n("Frame",sBadge,{Size=UDim2.fromOffset(7,7),Position=UDim2.new(0,0,.5,-3.5),BackgroundColor3=C.gray,BorderSizePixel=0}); U.round(sDot,4)
    local stateL=U.label(sBadge,"IDLE",12,C.sub,U.F.bold,{Size=UDim2.fromOffset(80,24),Position=UDim2.fromOffset(16,0),TextWrapped=false})
    -- goal picker (unavailable goals are dimmed and explain why)
    local grid=U.n("Frame",hero,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
    U.n("UIGridLayout",grid,{CellSize=UDim2.new(.333,-6,0,32),CellPadding=UDim2.fromOffset(6,6),SortOrder=Enum.SortOrder.LayoutOrder})
    local goalBtns={}
    for i,key in ipairs(GO and GO.order or {}) do
        local g=GO.goals[key]
        local b=U.n("TextButton",grid,{BackgroundColor3=C.card,Text=g.title,TextColor3=C.sub,TextSize=12,Font=U.F.semi,AutoButtonColor=false,BorderSizePixel=0,LayoutOrder=i})
        U.round(b,10); U.pressable(b,{hoverScale=1.02,pressScale=.96}); goalBtns[key]=b
        table.insert(RAVYN._connections,b.Activated:Connect(function()
            local ok=GO.available(key)
            if not ok then U.toast(g.title.." needs research first","warn"); return end
            local r=RAVYN:GoSetGoal(key); if r and not r.ok then U.report(r) end
        end))
    end
    local btnRow=U.n("Frame",hero,{Size=UDim2.new(1,0,0,52),BackgroundTransparency=1})
    local main=U.n("TextButton",btnRow,{Size=UDim2.new(1,-120,1,0),BackgroundColor3=C.goldDim,Text="START RAVYN",TextColor3=C.gold,TextSize=16,Font=U.F.bold,AutoButtonColor=false,BorderSizePixel=0})
    U.round(main,15); local mainStroke=U.stroke(main,C.gold,1,.42); U.pressable(main,{hoverScale=1.012,pressScale=.965,enterColor=Color3.fromRGB(76,64,30),leaveColor=C.goldDim})
    local stop=U.n("TextButton",btnRow,{Size=UDim2.new(0,108,1,0),Position=UDim2.new(1,-108,0,0),BackgroundColor3=C.redDim,Text="Stop",TextColor3=C.red,TextSize=14,Font=U.F.bold,AutoButtonColor=false,BorderSizePixel=0})
    U.round(stop,15); U.stroke(stop,C.red,1,.58); U.pressable(stop,{hoverScale=1.018,pressScale=.955,enterColor=Color3.fromRGB(76,24,26),leaveColor=C.redDim})
    local busy=false
    table.insert(RAVYN._connections,main.Activated:Connect(function()
        if busy then return end; busy=true
        local r
        if GO.active then r=RAVYN:GoPause() else r=RAVYN:Go(RAVYN.Config.Go.Goal) end
        if r and not r.ok then U.report(r) end
        task.delay(.3,function() busy=false end)
    end))
    table.insert(RAVYN._connections,stop.Activated:Connect(function()
        pcall(function() RAVYN:SetAutoPlay(false); RAVYN:SetKillAura(false); RAVYN:SetFeature("NORMAL_MOB",false); RAVYN:SetFeature("BOSS",false); RAVYN:Stop() end)
        task.delay(.35,function()
            local MO=RAVYN.MoveOwner or {}; local NC=RAVYN.NoclipController or {}; local CM=RAVYN.CombatMobility or {}
            local okStop=MO.current=="IDLE" and not NC.active and not CM.bodyVelocity and RAVYN.FSM.state=="STOPPED"
            U.toast(okStop and "Stopped" or "Stop incomplete · see Settings → Developer",okStop and "success" or "error")
        end)
    end))
    U.addRefresh(function(S)
        U.setText(goalL,string.upper(S.goalTitle))
        -- status badge
        local sColor=S.globalColor; local sLabel=S.global or "IDLE"
        U.setText(stateL,sLabel); U.setColor(stateL,"TextColor3",sColor); U.setColor(sDot,"BackgroundColor3",sColor); U.setColor(sBadge,"BackgroundColor3",U.dimOf(sColor))
        local st=S.go.state
        local label=(not S.go.active and "START RAVYN") or (S.go.paused and "RESUME RAVYN") or "PAUSE RAVYN"
        if not busy then U.setText(main,label) end
        local running=S.go.active and not S.go.paused
        U.setColor(main,"BackgroundColor3",running and C.raised or C.goldDim); U.setColor(main,"TextColor3",running and C.text or C.gold); U.setColor(mainStroke,"Color",running and C.line or C.gold)
        for key,b in pairs(goalBtns) do
            local on=key==S.go.goal; local ok=GO.available(key)
            U.setColor(b,"BackgroundColor3",on and C.goldDim or C.card)
            U.setColor(b,"TextColor3",(on and C.gold) or (ok and C.sub) or C.faint)
        end
    end)
    -- what RAVYN is doing
    local _,info=U.card(page,"Now","",{order=2})
    U.kv(info,"Current",function(S) return S.headline,C.text end,{size=14})
    U.kv(info,"Target",function(S) if not S.target then return "—",C.gray end; return (S.target.boss and "◆ " or "")..S.target.name..(S.target.hpPct and string.format("  ·  %d%%",math.floor(S.target.hpPct+.5)) or ""),S.target.boss and C.gold or C.text end,{size=14})
    U.kv(info,"Progress",function(S) return S.progressText,S.progressText=="—" and C.gray or C.purple end,{size=14})
    U.bar(info,function(S)
        if S.quest.progress and S.quest.required and S.quest.required>0 then return S.quest.progress/S.quest.required,C.purple end
        if S.loot.active and S.loot.detected>0 then return S.loot.collected/S.loot.detected,C.gold end
        if S.target and S.target.hpPct then return 1-S.target.hpPct/100,C.green end
        return 0,C.gray end)
    U.kv(info,"Next",function(S) return S.next,C.sub end,{size=14})
    local _,me=U.card(page,"You","",{order=3})
    U.kv(me,"Health",function(S) if S.dead then return "Down · respawning",C.red end; return S.hpPct and string.format("%d%%",math.floor(S.hpPct+.5)) or "—",U.hpColor(S.hpPct) end)
    U.bar(me,function(S) return (S.hpPct or 0)/100,U.hpColor(S.hpPct) end)
    U.kv(me,"Level",function(S) return S.level and tostring(S.level) or "—",C.text end)
    -- recent meaningful events
    local _,feed=U.card(page,"Recent","",{order=4,collapsible=true,collapsed=true})
    local lines={}
    for i=1,5 do lines[i]=U.label(feed,"",11,C.sub,U.F.body,{Size=UDim2.new(1,0,0,16),TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd}) end
    U.addRefresh(function()
        local f=(RAVYN.AutoPlay384 and RAVYN.AutoPlay384.feed) or {}
        for i=1,5 do
            local e=f[#f-i+1]
            if e then U.setText(lines[i],e.clock.."  "..e.text); U.setColor(lines[i],"TextColor3",(e.kind=="success" and C.green) or (e.kind=="warn" and C.orange) or (e.kind=="error" and C.red) or C.sub)
            else U.setText(lines[i],i==1 and "Nothing yet" or "") end
        end
    end)
end

-- ================= AUTO PLAY =================
function U.buildAutoPlay(page)
    local _,m=U.card(page,"Auto Play","One scheduler decides between quests, travel, combat and loot. Defense and emergencies interrupt, then the same task resumes.",{order=1})
    U.toggle(m,{label="Auto Play",desc="Master orchestrator",get=function() return cfg().Intelligence.AutoPlay end,set=function(v) return RAVYN:SetAutoPlay(v) end,
        status=function(S) return S.autoplay and S.activity or "OFF",S.autoplay and S.globalColor or C.gray end})
    U.segment(m,{"Smart","Bosses","Mobs"},function() return cfg().AutoPlayV38.Mode end,function(v) return RAVYN:SetAutoPlayMode(v) end)
    U.toggle(m,{label="Boss rotation",desc="Chain eligible bosses, skip respawning ones",get=function() return cfg().AutoPlayV38.BossRotation end,set=function(v) return RAVYN:SetAutoPlayBossRotation(v) end,dep=function() return cfg().AutoPlayV38.Mode=="Smart" end,depText="Only used in Smart mode"})
    U.toggle(m,{label="Farm while waiting",desc="Normal mobs when no boss or quest target is available",get=function() return cfg().AutoPlayV38.PreFarm end,set=function(v) return RAVYN:SetAutoPlayPreFarm(v) end,dep=function() return cfg().AutoPlayV38.Mode=="Smart" end,depText="Only used in Smart mode"})
    U.segment(m,{{"No limit",0},{"1 boss",1},{"3 bosses",3},{"5 bosses",5}},function() return cfg().AutoPlayV38.StopAfterBosses end,function(v) return RAVYN:SetAutoPlayStopAfterBosses(v) end)
    local schedCard,s=U.card(page,"Scheduler","Priority owner right now.",{order=2}); U.devOnly(schedCard)
    U.kv(s,"Job",function(S) return S.job.."  ·  P"..S.priority,S.globalColor end)
    U.kv(s,"Interrupt",function(S) return S.overlay or "none",S.overlay and C.gold or C.gray end)
    U.kv(s,"Movement owner",function(S) return S.owner,U.ownerColor(S.owner) end)
    U.kv(s,"Eligible bosses",function(S) return tostring(S.eligibleBosses),S.eligibleBosses>0 and C.gold or C.gray end)
    local capCard,cap=U.card(page,"Capabilities","Read from the single capability provider. Nothing is VERIFIED until live evidence confirms it.",{order=3,collapsible=true}); U.devOnly(capCard)
    for _,k in ipairs((RAVYN.GameKnowledge and RAVYN.GameKnowledge.capOrder) or {}) do U.capRow(cap,k) end
end

-- ================= QUESTS =================
function U.buildQuests(page)
    -- ── Crow Hunt hero card ──────────────────────────────────────────────────
    local crowCard,crow=U.card(page,"Crow Hunts","Boss Hunt missions issued by the Kasugai Crow.",{order=0,
        warn=function(S) return (S.questEnabled and not S.autoplay) and C.orange or nil end})
    U.kv(crow,"Status",function() local x=RAVYN.CrowDirect; if not x then return "Unavailable",C.red end; return x.status,(x.status=="ACTIVE" and C.green) or (x.status=="DAILY_COMPLETE" and C.gold) or (x.status=="COOLDOWN" and C.orange) or C.sub end)
    U.kv(crow,"Mission",function() local x=RAVYN.CrowDirect; if not x then return "—",C.gray end; return x.detail or x.mission or "—",C.text end)
    U.kv(crow,"Progress",function(S) if S.quest.source=="CROW" and S.quest.progress then return string.format("%d / %d",S.quest.progress,S.quest.required or 0),C.purple end; return "—",C.gray end)
    U.bar(crow,function(S) if S.quest.source=="CROW" and S.quest.progress and S.quest.required and S.quest.required>0 then return S.quest.progress/S.quest.required,C.purple end; return 0,C.purple end)
    U.kv(crow,"Next available",function() local x=RAVYN.CrowDirect; if not x then return "—",C.gray end; local cd=x.cooldown; return cd and tostring(cd) or (x.status=="DAILY_COMPLETE" and "Tomorrow") or "Now",cd and C.orange or C.green end)
    U.toggle(crow,{label="Auto Crow Hunts",desc="Open Crow → claim a Hunt → teleport → fight → loot → next",get=function() return RAVYN.Config.CrowDirect and RAVYN.Config.CrowDirect.Enabled end,set=function(v) return RAVYN:SetCrowHunts(v) end,
        status=function() local st=U.crowState and U.crowState() or "OFF"; return st,U.stateColor and U.stateColor(st) or C.sub end})
    U.devOnly(U.button(crow,"Reset Crow daily state",function() return RAVYN:ResetCrowDaily() end))
    -- ── Quest sources (advanced) ─────────────────────────────────────────────
    local _,c=U.card(page,"Other quest sources","Generic quests stay available; Muzan remains evidence-gated.",{order=1,
        warn=function(S) return (S.questEnabled and not S.autoplay) and C.orange or nil end})
    local qc=function() return cfg().QuestBrain end
    local qs=function(k) return function(v) return RAVYN:SetQuestOption(k,v) end end
    -- v3.8.5.1: Crow/Muzan automation is not claimed. Status comes from the capability provider.
    U.capRow(c,"CROW_MISSION")
    U.kv(c,"Crow Boss Hunts",function() local x=RAVYN.CrowDirect; if not x then return "Unavailable",C.red end; return x.status.." · "..(x.detail or ""), (x.status=="ACTIVE" and C.green) or (x.status=="DAILY_COMPLETE" and C.green) or C.gold end)
    U.devOnly(U.button(c,"Reset Crow daily state",function() return RAVYN:ResetCrowDaily() end))
    U.capRow(c,"MUZAN_HUNT")
    U.devOnly(U.label(c,"Record the Muzan task flow before automation is enabled.",11,C.sub,U.F.body))
    U.devOnly(U.button(c,"Research Muzan",function() if U.openResearch then U.openResearch("Muzan · task menu") end; return false end))
    U.toggle(c,{label="Other quest givers",desc="Generic quest/mission prompts",get=function() return qc().AutoQuest end,set=qs("AutoQuest")})
    U.devOnly(U.toggle(c,{label="Learn target by nearby kills",desc="Off: unresolved targets are investigated via quest markers only",get=function() return qc().LearnByNearbyKills end,set=qs("LearnByNearbyKills"),
        tip="When a quest does not name its target and no marker identifies it, ON farms nearby mobs and credits the kill that advanced the counter. OFF waits for evidence."}))
    U.toggle(c,{label="Auto turn-in",desc="Return to the source when the objective completes",get=function() return qc().AutoTurnIn end,set=qs("AutoTurnIn"),
        dep=function() return qc().AutoQuest end,depText="Enable a quest source first"})
    local _,q=U.card(page,"Current quest","",{order=2,warn=function(S) local e=U.explain(S.quest.fail); return (e and e.color~=C.gold) and e.color or nil end})
    U.kv(q,"Source",function(S) return S.quest.source..(S.quest.sourceName and ("  ·  "..S.quest.sourceName) or ""),S.quest.source=="CROW" and C.purple or (S.quest.source=="MUZAN" and C.red or C.sub) end)
    U.kv(q,"Doing",function(S) return S.plain,C.text end)
    U.devRow(U.kv(q,"State",function(S) return S.quest.state,(S.quest.fail and C.orange) or C.purple end))
    U.kv(q,"Objective",function(S) return S.quest.objective,C.text end)
    U.kv(q,"Target",function(S) if S.quest.target then return S.quest.target,C.text end; return (S.quest.objective=="KILL") and "Learning…" or "—",C.gold end)
    U.devRow(U.kv(q,"Confidence",function(S) local c2=S.quest.confidence; return c2,(c2=="VERIFIED" and C.green) or (c2=="HIGH" and C.green) or (c2=="TEXT MATCH" and C.cyan) or C.gold end))
    U.kv(q,"Progress",function(S) if S.quest.progress then return string.format("%d / %d",S.quest.progress,S.quest.required or 0),S.quest.stalled and C.orange or C.green end; return "—",C.gray end)
    U.bar(q,function(S) if S.quest.progress and S.quest.required and S.quest.required>0 then return S.quest.progress/S.quest.required,C.purple end; return 0,C.purple end)
    U.devRow(U.kv(q,"Navigation",function(S) if S.quest.nav then return S.owner=="TRAVEL" and S.travelMode or "ARRIVED",C.cyan end; return (S.target and S.owner) or "—",U.ownerColor(S.owner) end))
    U.devRow(U.kv(q,"Level",function(S) return S.quest.level and ("Lv "..S.quest.level) or "—",C.sub end))
    U.kv(q,"Completed",function(S) return string.format("%d this session",S.quest.completed),C.sub end)
    U.devRow(U.kv(q,"Data cross-check",function()
        local d=RAVYN.QuestBrain and RAVYN.QuestBrain.dataCheck; if not d then return "—",C.gray end
        return d.agreement..(#d.dataQuests>0 and ("  ·  data: "..table.concat(d.dataQuests,", ")) or ""),(d.agreement=="MATCH" and C.green) or (d.agreement=="BOTH_EMPTY" and C.gray) or C.orange end))
    U.devRow(U.kv(q,"QuestStates identity",function()
        local id=RAVYN.QuestBrain and RAVYN.QuestBrain.questIdentity; return id or "—",id and C.cyan or C.gray end))
    U.warning(q,function(S) return S.quest.fail end)
    local prCard,pr=U.card(page,"QuestProbe","Evidence capture only. Quest reading stays UNRESOLVED until live before/after pairs map it. Snapshots are taken automatically around accept, kill and turn-in.",{order=3,collapsible=true,collapsed=true}); U.devOnly(prCard)
    U.kv(pr,"Captured pairs",function() local QB=RAVYN.QuestBrain; local n=QB and QB.probe and #QB.probe.reports or 0; return tostring(n),n>0 and C.green or C.gray end)
    U.button(pr,"Manual snapshot (press before, then after)",function() return RAVYN:CaptureQuestProbe("MANUAL") end,"accent")
    U.button(pr,"Copy QuestProbe report",function() return RAVYN:CopyQuestProbeReport() end)
end

-- ================= FARM =================
function U.buildFarm(page)
    local _,f=U.card(page,"Manual farm","Used when Auto Play is off.",{order=1})
    U.segment(f,{"Normal","Boss","Off"},function()
        if cfg().Farm.Boss.Enabled then return "Boss" elseif cfg().Farm.NormalMobs.Enabled then return "Normal" end; return "Off" end,
        function(v)
            if v=="Normal" then RAVYN:SetFeature("BOSS",false); return RAVYN:SetFeature("NORMAL_MOB",true)
            elseif v=="Boss" then RAVYN:SetFeature("NORMAL_MOB",false); return RAVYN:SetFeature("BOSS",true) end
            RAVYN:SetFeature("NORMAL_MOB",false); return RAVYN:SetFeature("BOSS",false)
        end,{dep=function() return not cfg().Intelligence.AutoPlay end,depText="Auto Play is controlling targets"})
    U.toggle(f,{label="Kill aura",desc="Nearest mob in range, no manual target",get=function() return cfg().Intelligence.KillAura.Enabled end,set=function(v) return RAVYN:SetKillAura(v) end})
    U.segment(f,{"Near","Normal","Wide","Stream"},function() return cfg().Intelligence.SearchRadius end,function(v) return RAVYN:SetSearchRadiusPreset(v) end)
    U.kv(f,"Current target",function(S) if not S.target then return "Scanning…",C.gray end; return (S.target.boss and "◆ " or "")..S.target.name.."  ·  "..U.fmtDist(S.target.dist),S.target.boss and C.gold or C.green end)
    local _,p=U.card(page,"Target picker","Live streamed NPCs. Tap to lock the farm target.",{order=2})
    local search=U.n("TextBox",p,{Size=UDim2.new(1,0,0,34),BackgroundColor3=C.card,Text="",PlaceholderText="Filter by name…",PlaceholderColor3=C.faint,TextColor3=C.text,TextSize=12,Font=U.F.body,ClearTextOnFocus=false,BorderSizePixel=0,TextXAlignment=Enum.TextXAlignment.Left}); U.round(search,9); U.pad(search,12,12,0,0)
    U.button(p,"Any / nearest",function() search.Text=""; return RAVYN:SetFarmTarget("Any",false) end,"accent")
    local rows={}
    for i=1,6 do
        local r=U.n("TextButton",p,{Size=UDim2.new(1,0,0,36),BackgroundColor3=C.card,Text="",AutoButtonColor=false,BorderSizePixel=0,Visible=false}); U.round(r,9)
        local b=U.label(r,"",10,C.faint,U.F.bold,{Size=UDim2.fromOffset(52,36),Position=UDim2.fromOffset(12,0),TextWrapped=false})
        local nm=U.label(r,"",12,C.text,U.F.semi,{Size=UDim2.new(1,-220,1,0),Position=UDim2.fromOffset(66,0),TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd})
        local hp=U.label(r,"",11,C.sub,U.F.mono,{Size=UDim2.fromOffset(70,36),Position=UDim2.new(1,-150,0,0),TextXAlignment=Enum.TextXAlignment.Right,TextWrapped=false})
        local d=U.label(r,"",11,C.sub,U.F.body,{Size=UDim2.fromOffset(66,36),Position=UDim2.new(1,-76,0,0),TextXAlignment=Enum.TextXAlignment.Right,TextWrapped=false})
        rows[i]={r=r,b=b,nm=nm,hp=hp,d=d}
        table.insert(RAVYN._connections,r.MouseEnter:Connect(function() U.anim(r,.1,{BackgroundColor3=C.raised}) end))
        table.insert(RAVYN._connections,r.MouseLeave:Connect(function() U.anim(r,.14,{BackgroundColor3=C.card}) end))
        table.insert(RAVYN._connections,r.Activated:Connect(function()
            local name=r:GetAttribute("npc"); if not name then return end
            local boss=r:GetAttribute("boss")==true
            U.report(RAVYN:SetFarmTarget(name,boss),"Target · "..name)
        end))
    end
    U.addRefresh(function()
        local list=RAVYN:GetObservedNPCs("ALL",6,search.Text) or {}
        for i,row in ipairs(rows) do
            local x=list[i]; row.r.Visible=x~=nil
            if x then
                row.r:SetAttribute("npc",x.name); row.r:SetAttribute("boss",x.isBoss==true)
                U.setText(row.b,x.isBoss and "◆ BOSS" or "MOB"); U.setColor(row.b,"TextColor3",x.isBoss and C.gold or C.faint)
                U.setText(row.nm,x.name)
                local pct=(x.health and x.maxHealth and x.maxHealth>0) and math.floor(x.health/x.maxHealth*100+.5) or nil
                U.setText(row.hp,pct and (pct.."%") or "—"); U.setColor(row.hp,"TextColor3",U.hpColor(pct))
                U.setText(row.d,U.fmtDist(x.distance))
            end
        end
    end)
end
return true]==========]); if not ok then return end end
do local ok=runChunk("UI384_PagesB.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local result=CTX["result"]
local currentSkillKeys=CTX["currentSkillKeys"]
local U=CTX["UI384"]
local C=U.C
local function cfg() return RAVYN.Config end
local function cm() return RAVYN.Config.CombatMobility end
local function setc(path) return function(v) return RAVYN:SetConfig(path,v) end end

-- ================= COMBAT =================
function U.buildCombat(page)
    local _,live=U.card(page,"Live combat","",{order=1,warn=function(S) local e=U.explain(S.skillFail); return (e and (e.color==C.red or e.color==C.orange)) and e.color or nil end})
    U.kv(live,"Target",function(S) if not S.target then return "None",C.gray end; return (S.target.boss and "◆ " or "")..S.target.name,S.target.boss and C.gold or C.text end)
    U.bar(live,function(S) if S.target and S.target.hpPct then return S.target.hpPct/100,U.hpColor(S.target.hpPct) end; return 0,C.gray end,8)
    U.kv(live,"Distance",function(S) return S.target and U.fmtDist(S.target.dist) or "—",C.sub end)
    U.devRow(U.kv(live,"Hover",function(S) return S.hover,(string.find(S.hover,"LOCKED",1,true) and C.green) or (S.hover=="FOLLOWING" and C.cyan) or (S.hover=="DEFENSE OVERRIDE" and C.gold) or C.gray end))
    U.kv(live,"Doing",function(S) return S.plain,(S.plain=="Recovering" and C.red) or C.text end)
    U.devRow(U.kv(live,"Combo",function(S)
        local t=S.combo>0 and ("M1 ×"..S.combo) or "—"
        if S.lastSkill and S.now-S.lastSkillAt<1.5 then t=t.."  →  Skill "..tostring(S.lastSkill) end
        return t,C.text end))
    U.devRow(U.kv(live,"Combat state",function(S) local st=S.combatState; return st,(st=="RECOVERY" and C.red) or (st=="DEFENSE_INTERRUPT" and C.gold) or (st=="SKILL_CAST" and C.cyan) or (st=="APPROACH" and C.cyan) or (st=="IDLE" and C.gray) or C.green end))
    U.devRow(U.kv(live,"Next action",function(S) return S.nextAction,C.text end))
    U.kv(live,"Last skill",function(S) if not S.lastSkill then return "—",C.gray end; local v=S.lastSkillVerdict or "?"; return tostring(S.lastSkill).."  ·  "..v,(v=="VERIFIED" and C.green) or (v=="CASTING" and C.cyan) or C.orange end)
    U.kv(live,"Skills",function(S) return string.format("%d found  ·  %d confirmed casts",S.discovered,S.verified),S.verified>0 and C.green or (S.skills>0 and C.orange or C.sub) end)
    U.kv(live,"Defense",function(S) return S.defense,S.defense=="READY" and C.green or C.gold end)
    U.devRow(U.kv(live,"Recovery",function(S) return S.recovery,(S.recovery=="STANDBY" and C.gray) or (string.find(S.recovery,"RESUMING",1,true) and C.green) or C.red end))
    U.devRow(U.kv(live,"M1 sent",function(S) return tostring(S.m1),C.sub end))
    U.warning(live,function(S) local f=S.skillFail; if f=="OK" or f=="IDLE" or f=="COMBO_WAIT_M1" then return nil end; return f end)
    local _,e=U.card(page,"Combat","RAVYN finds your skills and uses them automatically.",{order=2})
    U.segment(e,{{"Safe","SAFE"},{"Fast","FAST"},{"Max","MAX"}},function() return cm().CombatSpeed end,setc("CombatMobility.CombatSpeed"))
    U.label(e,"Max = fastest verified combat (adaptive M1 + confirmed skills). No fake instant kills.",11,C.sub,U.F.body)
    U.kv(e,"One hit",function()
        local IK=RAVYN.InstaKillAdapter
        if IK and IK.activeClass and IK.activeClass()=="THRESHOLD_99" then return "THRESHOLD FINISHER · 99% · TRUE ONE-HIT: NO VALID PATH",C.gold end
        return "MAX BURST · TRUE ONE-HIT: NO VALID PATH",C.orange end)
    U.toggle(e,{label="Auto attack",get=function() return cfg().Combat.AutoAttack end,set=function(v) return RAVYN:SetFeature("ATTACK",v) end,
        status=function(S,on) if not on then return "OFF",C.gray end; return S.target and "FIRING" or "READY",S.target and C.green or C.sub end})
    U.toggle(e,{label="Smart skills",desc="Finds your hotbar keys and learns cooldowns",get=function() return cfg().Combat.AutoAbilities end,set=function(v) return RAVYN:SetFeature("ABILITIES",v) end,
        status=function(S,on)
            if not on then return "OFF",C.gray end
            local x=U.explain(S.skillFail); if S.skillFail=="OK" then return "FIRING",C.green end
            if S.discovered==0 then return x and string.upper(x.title) or "NO HOTBAR",C.orange end
            return S.discovered.." FOUND",C.sub end})
    U.devOnly(U.toggle(e,{label="Hold combo",desc="M1 chain, then decide: skill or continue",get=function() return cm().HoldCombo end,set=setc("CombatMobility.HoldCombo"),dep=function() return cfg().Combat.AutoAttack end,depText="Needs Auto attack"}))
    U.devOnly(U.segment(e,{{"2 hits",2},{"3 hits",3},{"4 hits",4},{"5 hits",5}},function() return cm().ComboLength end,setc("CombatMobility.ComboLength"),{dep=function() return cm().HoldCombo end,depText="Needs Hold combo"}))
    U.devOnly(U.toggle(e,{label="Turbo M1 · experimental",desc="0.09s cadence; overrides Combat Speed",get=function() return cm().TurboM1 end,set=setc("CombatMobility.TurboM1"),dep=function() return cfg().Combat.AutoAttack end,depText="Needs Auto attack"}))
    U.devOnly(U.toggle(e,{label="Aggressive skills",desc="Shorter skill interval",get=function() return cm().AggressiveSkills end,set=setc("CombatMobility.AggressiveSkills"),dep=function() return cfg().Combat.AutoAbilities end,depText="Needs Auto skills"}))
    U.toggle(e,{label="Keep combo while hit",desc="Normal damage keeps the combo",get=function() return cm().KeepComboUnderHit end,set=setc("CombatMobility.KeepComboUnderHit")})
    U.toggle(e,{label="Recovery",desc="Auto-recover from ragdoll, falling and physics states",get=function() return cm().NoRagdoll end,set=function(v) RAVYN:SetConfig("CombatMobility.AntiRagdoll",v); return RAVYN:SetConfig("CombatMobility.NoRagdoll",v) end,
        status=function(S,on) return on and (tostring(S.mitigation.ragdoll or 0).." FIXED") or "OFF",on and C.green or C.gray end})
    U.toggle(e,{label="Adaptive defense",desc="Reactive dodge and guard against verified threats",get=function() return cfg().CombatEvolution.Defense.AdaptiveDodge end,set=setc("CombatEvolution.Defense.AdaptiveDodge")})
    U.toggle(e,{label="Low HP safety escape",desc="OFF = keep your chosen combat height even when HP is low",get=function() return cfg().SmartCombat.HealthSafetyEscape end,set=setc("SmartCombat.HealthSafetyEscape")})
    -- Combat positioning (quick access – full controls also on Travel)
    local _,pos=U.card(page,"Combat positioning","Hover position while fighting. Full controls on Travel page.",{order=3})
    U.toggle(pos,{label="Combat hover",get=function() return cm().FlyFarmFight end,set=setc("CombatMobility.FlyFarmFight"),
        status=function(S,on) if not on then return "OFF",C.gray end; return (string.find(S.hover,"LOCKED",1,true) and "LOCKED") or S.hover,(string.find(S.hover,"LOCKED",1,true) and C.green) or C.sub end})
    U.segment(pos,{{"Above","ABOVE"},{"Behind","ABOVE_BEHIND"},{"Orbit","ORBIT_HOVER"}},function() return cm().HoverMode end,setc("CombatMobility.HoverMode"),{dep=function() return cm().FlyFarmFight end,depText="Enable Combat hover first"})
    U.label(pos,"Height",12,C.sub,U.F.semi)
    U.segment(pos,{{"3",3},{"5",5},{"8",8},{"12",12},{"18",18},{"25",25}},function() return cm().FlyHeight end,setc("CombatMobility.FlyHeight"),{dep=function() return cm().FlyFarmFight end,depText="Enable Combat hover first"})
    U.label(pos,"Distance",12,C.sub,U.F.semi)
    U.segment(pos,{{"2",2},{"3",3},{"5",5},{"8",8},{"12",12},{"16",16}},function() return cm().HoverDistance or 3 end,setc("CombatMobility.HoverDistance"),{dep=function() return cm().FlyFarmFight end,depText="Enable Combat hover first"})
    U.devOnly(U.toggle(e,{label="Smart safety",desc="Risk engine telemetry and advanced safety logic",get=function() return cfg().SmartCombat.Enabled end,set=setc("SmartCombat.Enabled")}))
    local _,mit=U.card(page,"Control mitigation","Client-side, best effort. The server may reapply its own states.",{order=4,collapsible=true})
    U.toggle(mit,{label="No ragdoll",desc="Recover from ragdoll / falling / physics states",get=function() return cm().NoRagdoll end,set=function(v) RAVYN:SetConfig("CombatMobility.AntiRagdoll",v); return RAVYN:SetConfig("CombatMobility.NoRagdoll",v) end,
        status=function(S,on) return on and (tostring(S.mitigation.ragdoll or 0).." FIXED") or "OFF",on and C.green or C.gray end})
    U.toggle(mit,{label="No stun",desc="Clears observed local stun values; may be reapplied",get=function() return cm().NoStun end,set=function(v) RAVYN:SetConfig("CombatMobility.AntiStun",v); return RAVYN:SetConfig("CombatMobility.NoStun",v) end,
        status=function(S,on) return on and (tostring(S.mitigation.stun or 0).." CLEARED") or "OFF",on and C.orange or C.gray end})
    U.toggle(mit,{label="No knockback",desc="Dampens large horizontal launches outside hover",get=function() return cm().NoKnockback end,set=setc("CombatMobility.NoKnockback"),
        status=function(S,on) return on and (tostring(S.mitigation.knockback or 0).." DAMPED") or "OFF",on and C.orange or C.gray end})
    U.toggle(mit,{label="No attack slowdown",desc="Only acts on an observed local slowdown source",get=function() return cm().NoAttackSlowdown end,set=setc("CombatMobility.NoAttackSlowdown"),
        status=function(S,on) return on and "NO SOURCE" or "OFF",on and C.orange or C.gray end})
    local testCard,t=U.card(page,"Input test","",{order=5,collapsible=true,collapsed=true}); U.devOnly(testCard)
    U.button(t,"Request one M1 (bus)",function() return RAVYN.CombatActionBus:RequestAttack(nil,{manual=true,source="UI test"}) end,"accent")
    U.button(t,"Request next skill (bus)",function() local k=currentSkillKeys(); if #k==0 then return result(false,"NO_VISIBLE_SKILL_KEYS") end; return RAVYN.CombatActionBus:RequestSkill(k[1],nil,{manual=true,source="UI test"}) end)
end

-- ================= LOOT =================
function U.buildLoot(page)
    local lc=function() return cfg().Loot384 end
    local lo=function(k) return function(v) return RAVYN:SetLootOption(k,v) end end
    local _,o=U.card(page,"Loot","Items are only counted when they are actually picked up.",{order=1,warn=function(S) return S.loot.fail and C.orange or nil end})
    U.toggle(o,{label="Auto loot",desc="Collect everything the enemy you killed drops",get=function() return lc().AutoLootAfterKill end,set=lo("AutoLootAfterKill")})
    U.toggle(o,{label="Boss chests",desc="Open the boss chest and nearby chests, collect everything",get=function() return lc().AutoLootChests end,set=lo("AutoLootChests")})
    U.devOnly(U.toggle(o,{label="Collect nearby loot",desc="Also take clearly-classified drops not spawned by this kill",get=function() return lc().CollectNearbyLoot end,set=lo("CollectNearbyLoot"),
        tip="Off: only drops that appeared after the kill/chest are collected. On: any nearby prompt classified as a drop."}))
    local card,s=U.card(page,"Loot session","",{order=2})
    U.kv(s,"Status",function(S)
        local st=S.loot.state
        local plain=(not S.loot.active and st~="COMPLETE" and "Standby") or (st=="COMPLETE" and "Done") or (string.find(st,"COLLECTING",1,true) and "Collecting")
            or ((st=="SEARCHING_CHEST" or st=="CHEST_FOUND" or st=="TRAVELING") and "Going to chest") or (st=="OPENING" and "Opening chest")
            or (st=="CHEST_NOT_FOUND" and "No chest found") or (string.find(st,"PAUSED",1,true) and "Waiting") or "Looting"
        return plain,(S.loot.active and C.gold) or (st=="COMPLETE" and C.green) or C.gray end)
    U.devRow(U.kv(s,"State",function(S) return S.loot.state,(S.loot.active and C.gold) or (S.loot.state=="COMPLETE" and C.green) or C.gray end))
    local detail=U.n("Frame",s,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1}); U.list(detail,8)
    U.devRow(U.kv(detail,"Drops detected",function(S) return tostring(S.loot.detected),C.text end))
    U.kv(detail,"Collected",function(S) return string.format("%d / %d",S.loot.collected,S.loot.detected),S.loot.collected>0 and C.green or C.sub end)
    U.bar(detail,function(S) if S.loot.detected>0 then return S.loot.collected/S.loot.detected,C.gold end; return 0,C.gold end)
    U.devRow(U.kv(detail,"Unverified",function(S) return tostring(S.loot.unverified),S.loot.unverified>0 and C.orange or C.sub end))
    U.kv(s,"Boss defeated",function(S) return S.loot.boss or "—",S.loot.boss and C.gold or C.gray end)
    U.kv(s,"Chest",function(S) return S.loot.chestExpected or "—",S.loot.chestExpected and C.text or C.gray end)
    U.devRow(U.kv(s,"Chest state",function(S) local c2=S.loot.chest; return c2..(S.loot.chestVia and ("  ·  "..S.loot.chestVia) or ""),(c2=="OPEN_VERIFIED" and C.green) or (c2=="NOT_FOUND" or c2=="INTERACTION_UNRESOLVED" or c2=="OPEN_UNVERIFIED") and C.orange or C.sub end))
    U.devRow(U.kv(detail,"Attempted",function(S) return tostring(S.loot.attempted),C.sub end))
    U.devRow(U.kv(detail,"Remaining",function(S) return tostring(S.loot.remaining),S.loot.remaining>0 and C.gold or C.sub end))
    U.kv(s,"Last session",function(S) return S.loot.last,C.sub end)
    U.devRow(U.kv(s,"Interaction",function() local f=(getgenv and getgenv().fireproximityprompt) or fireproximityprompt; if type(f)=="function" then return "fireproximityprompt · PARTIAL",C.orange end; return "UNRESOLVED_GAME_BINDING",C.red end))
    U.warning(s,function(S) return S.loot.fail end)
    U.devOnly(U.button(s,"Copy loot probe",function() return RAVYN:CopyLootProbe() end))
    local hCard,h=U.card(page,"Death → loot handoff","Proves whether a target death reached the loot controller.",{order=3,collapsible=true})
    U.devOnly(hCard)
    U.kv(h,"Target session",function(S) local x=S.handoff; if not x.session then return "none",C.gray end; return "#"..tostring(x.session)..(x.sessionName and ("  ·  "..x.sessionName) or "")..(x.source and ("  ·  "..x.source) or ""),C.text end)
    U.kv(h,"Death listener",function(S) return S.handoff.listener,S.handoff.listener=="ATTACHED" and C.green or C.gray end)
    U.kv(h,"Chest cached",function(S) return tostring(S.handoff.sessionChest or "—"),S.handoff.sessionChest and C.green or C.gray end)
    U.kv(h,"Death detected by",function(S) return tostring(S.handoff.deathBy or "—"),S.handoff.deathBy and C.green or C.gray end)
    U.kv(h,"Death handled",function(S) return S.handoff.handled and "YES" or "NO",S.handoff.handled and C.green or C.gray end)
    U.kv(h,"Boss loot context",function(S) return S.handoff.context,S.handoff.context=="CREATED" and C.green or C.gray end)
    U.kv(h,"StartKillLoot",function(S) if not S.handoff.startCalled then return S.handoff.startResult and ("NOT CALLED · "..S.handoff.startResult) or "NOT CALLED",C.gray end; return "CALLED · "..tostring(S.handoff.startResult),(S.handoff.startResult=="LOOT_SESSION_STARTED") and C.green or C.orange end)
    U.kv(h,"Lost targets",function(S) return tostring(S.handoff.lost),C.sub end)
    local wasActive=nil
    U.addRefresh(function(S)
        local show=S.loot.active or S.loot.state=="COMPLETE"
        if show~=wasActive then wasActive=show; detail.Visible=show end
    end)
end

-- ================= TRAVEL =================
function U.buildTravel(page)
    local tc=function() return cfg().TravelController end
    local _,m=U.card(page,"Movement owner","Exactly one system moves the character at a time.",{order=1})
    local chipRow=U.n("Frame",m,{Size=UDim2.new(1,0,0,26),BackgroundTransparency=1})
    local chip,chipL=U.chip(chipRow,function(S) return S.owner=="COMBAT_HOVER" and "COMBAT HOVER" or S.owner,U.ownerColor(S.owner) end,170)
    -- v3.8.4.3: no size bounce on owner changes (owner flips on every dodge); colour transition only (cached in U.chip)
    U.kv(m,"Reason",function(S) return S.moveReason~="" and S.moveReason or "—",C.sub end)
    U.kv(m,"Travel mode",function(S) return S.travelMode,(S.travelMode=="TELEPORT" and C.gold) or C.cyan end)
    U.kv(m,"Noclip",function(S) return S.noclip and "ON · collision cached" or "OFF · collision normal",S.noclip and C.cyan or C.gray end)
    U.kv(m,"Session",function(S) return string.format("%d teleports · %d tweens",S.teleports,S.tweens),C.sub end)
    local _,t=U.card(page,"Direct travel","All navigation uses teleport. No distance cap.",{order=2})
    U.toggle(t,{label="Teleport only",desc="Quest, boss, loot and normal travel use instant teleport",get=function() return tc().TeleportOnly end,set=setc("TravelController.TeleportOnly")})
    U.toggle(t,{label="Unlimited travel range",desc="Targets are not rejected because they are far away",get=function() return tc().UnlimitedRange end,set=setc("TravelController.UnlimitedRange")})
    U.toggle(t,{label="Return to boss after death",desc="If you die while fighting a boss, teleport back after respawn",get=function() return tc().ReturnToBossOnRespawn end,set=setc("TravelController.ReturnToBossOnRespawn")})
    U.kv(t,"Mode",function() return tc().TeleportOnly and "TELEPORT ONLY · NO DISTANCE LIMIT" or "LEGACY HYBRID",tc().TeleportOnly and C.green or C.orange end)
    U.toggle(t,{label="Travel noclip",desc="No collision while teleport/travel owns movement",get=function() return tc().TravelNoclip end,set=setc("TravelController.TravelNoclip"),
        tip="Collision is cached per part and restored exactly when travel ends, on Stop, respawn or Destroy."})
    local _,h=U.card(page,"Combat hover","Above and slightly behind the target; follows its height.",{order=3})
    U.toggle(h,{label="Combat hover",get=function() return cm().FlyFarmFight end,set=setc("CombatMobility.FlyFarmFight"),
        status=function(S,on) if not on then return "OFF",C.gray end; return (string.find(S.hover,"LOCKED",1,true) and "LOCKED") or S.hover,(string.find(S.hover,"LOCKED",1,true) and C.green) or C.sub end})
    U.segment(h,{{"Above","ABOVE"},{"Behind","ABOVE_BEHIND"},{"Orbit","ORBIT_HOVER"}},function() return cm().HoverMode end,setc("CombatMobility.HoverMode"),{dep=function() return cm().FlyFarmFight end,depText="Enable Combat hover first"})
    U.label(h,"Height above target",12,C.sub,U.F.semi)
    U.segment(h,{{"3",3},{"5",5},{"8",8},{"12",12},{"18",18},{"25",25}},function() return cm().FlyHeight end,setc("CombatMobility.FlyHeight"),{dep=function() return cm().FlyFarmFight end,depText="Enable Combat hover first"})
    U.label(h,"Horizontal distance from target",12,C.sub,U.F.semi)
    U.segment(h,{{"2",2},{"3",3},{"5",5},{"8",8},{"12",12},{"16",16}},function() return cm().HoverDistance or 3 end,setc("CombatMobility.HoverDistance"),{dep=function() return cm().FlyFarmFight end,depText="Enable Combat hover first"})
    U.toggle(h,{label="Low HP safety escape",desc="OFF = never climb/retreat just because your HP drops",get=function() return cfg().SmartCombat.HealthSafetyEscape end,set=setc("SmartCombat.HealthSafetyEscape")})
    U.toggle(h,{label="Combat noclip",desc="No collision while hover owns movement",get=function() return tc().CombatNoclip end,set=setc("TravelController.CombatNoclip"),dep=function() return cm().FlyFarmFight end,depText="Enable Combat hover first",
        tip="Disables character collision while Combat Hover owns movement. Original collision is restored when combat ends."})
    local _,p=U.card(page,"Saved places","Positions you recorded yourself.",{order=4,collapsible=true})
    U.button(p,"Save current position",function() return RAVYN:SaveCurrentPlace() end,"accent")
    local btns={}
    for i=1,5 do
        local b=U.button(p,"",function() return RAVYN:TeleportToSavedPlace(i) end); b.Visible=false; btns[i]=b
    end
    U.addRefresh(function()
        local list=cfg().Intelligence.SavedPlaces or {}
        for i,b in ipairs(btns) do local x=list[i]; b.Visible=x~=nil; if x then U.setText(b,"Teleport · "..tostring(x.name)) end end
    end)
end

-- ================= INTELLIGENCE =================
function U.buildIntelligence(page)
    local _,e=U.card(page,"Combat evolution","Threat learning, face lock and defense. Dodges only fire for evidence-backed threats.",{order=1})
    U.toggle(e,{label="Face lock",get=function() return cfg().CombatEvolution.FaceLock end,set=setc("CombatEvolution.FaceLock")})
    U.toggle(e,{label="Adaptive dodge",desc="Needs 6 sightings · 4 impacts · 70% correlation",get=function() return cfg().CombatEvolution.Defense.AdaptiveDodge end,set=setc("CombatEvolution.Defense.AdaptiveDodge")})
    U.toggle(e,{label="Reactive guard",get=function() return cfg().CombatEvolution.Defense.ReactiveGuard end,set=setc("CombatEvolution.Defense.ReactiveGuard")})
    U.toggle(e,{label="Skill learning",desc="Scores each discovered key by observed damage",get=function() return cfg().CombatEvolution.Learning.Enabled end,set=setc("CombatEvolution.Learning.Enabled")})
    U.toggle(e,{label="Heavy attack (M2)",desc="Off by default until M2 is verified",get=function() return cfg().CombatEvolution.UseHeavyAttack end,set=setc("CombatEvolution.UseHeavyAttack"),
        status=function(_,on) return on and "UNVERIFIED" or "OFF",on and C.orange or C.gray end})
    U.kv(e,"Status",function()
        local ok,r=pcall(function() return RAVYN:GetCombatEvolutionStatus() end)
        local v=ok and r and r.value or {}
        return tostring(v.status or "—"),C.gold end)
    local _,s=U.card(page,"Skill intelligence","Keys come from the live hotbar KeyLabels. A cast counts only with GUI, animation or damage evidence; cooldowns are learned from the slot GUI.",{order=2})
    local strip=U.n("Frame",s,{Size=UDim2.new(1,0,0,62),BackgroundTransparency=1}); U.list(strip,6,Enum.FillDirection.Horizontal)
    local empty=U.label(s,"No active skill hotbar",12,C.orange,U.F.semi)
    local chips={}
    for i=1,10 do
        local f=U.n("Frame",strip,{Size=UDim2.new(.1,-6,1,0),BackgroundColor3=C.card,BorderSizePixel=0,Visible=false,LayoutOrder=i}); U.round(f,9)
        local k=U.label(f,"",15,C.text,U.F.bold,{Size=UDim2.new(1,0,0,22),Position=UDim2.fromOffset(0,4),TextXAlignment=Enum.TextXAlignment.Center,TextWrapped=false})
        local st=U.label(f,"",9,C.sub,U.F.bold,{Size=UDim2.new(1,0,0,14),Position=UDim2.fromOffset(0,27),TextXAlignment=Enum.TextXAlignment.Center,TextWrapped=false})
        local star=U.label(f,"",9,C.gold,U.F.body,{Size=UDim2.new(1,0,0,14),Position=UDim2.fromOffset(0,42),TextXAlignment=Enum.TextXAlignment.Center,TextWrapped=false})
        chips[i]={f=f,k=k,st=st,star=star}
    end
    U.addRefresh(function(S)
        local ok,keys=pcall(currentSkillKeys); keys=ok and keys or {}
        local stats=(RAVYN.CombatEvolution and RAVYN.CombatEvolution.skillStats) or {}
        local maxD=0; for _,x in ipairs(keys) do local st=stats[x.key]; if st and (st.avgDamage or 0)>maxD then maxD=st.avgDamage end end
        empty.Visible=#keys==0
        for i,c in ipairs(chips) do
            local x=keys[i]; c.f.Visible=x~=nil
            if x then
                local st=stats[x.key] or {}; local n=st.samples or 0
                local ex=S.skillStats[x.key]
                local r=(S.readiness and S.readiness(x.key,S.now)) or "LEARNING"
                local col=(r=="READY" and C.green) or (r=="CASTING" and C.gold) or (r=="BACKOFF" and C.red) or ((r=="COOLDOWN" or r=="COOLDOWN_LEARNING") and C.cyan) or C.orange
                U.setText(c.k,x.key)
                U.setText(c.st,r=="COOLDOWN_LEARNING" and "CD LEARN" or r)
                U.setColor(c.st,"TextColor3",col)
                U.setColor(c.f,"BackgroundColor3",r=="CASTING" and C.goldDim or C.card,.12)
                if ex and ex.sent>0 then
                    U.setText(c.star,string.format("%d%%%s",math.floor(ex.verified/ex.sent*100+.5),ex.cooldown and string.format(" %.1fs",ex.cooldown) or ""))
                else
                    local stars=(maxD>0 and n>0) and math.max(1,math.ceil((st.avgDamage or 0)/maxD*5)) or 0
                    U.setText(c.star,n>0 and string.rep("★",stars)..string.rep("·",5-stars) or "·····")
                end
            end
        end
    end)
    local _,a=U.card(page,"Adaptive loadout","Each hotbar fingerprint keeps its own learned profile.",{order=3,collapsible=true})
    U.kv(a,"Loadout generation",function() local A=RAVYN.AdaptiveIntel; return tostring(A and A.loadoutGeneration or 0),C.sub end)
    U.kv(a,"Known profiles",function() local A=RAVYN.AdaptiveIntel; local n=0; if A then for _ in pairs(A.profiles or {}) do n=n+1 end end; return tostring(n),C.sub end)
    U.kv(a,"Status",function() local A=RAVYN.AdaptiveIntel; return tostring(A and A.status or "—"),C.sub end)
end

-- ================= DUNGEON =================
function U.buildDungeon(page)
    local _,d=U.card(page,"Ouwigahara","Architecture is in place. Each step unlocks only after its exact game action is verified.",{order=1})
    for _,x in ipairs({{"JOIN_OUWLAND","Join"},{"OUWI_QUEUE","Queue normal"},{"READY","Ready up"},{"OUWI_FARM","Floor combat"},{"CARD","Card choice"},{"VOTE","Vote skip"},{"LEAVE","Leave after run"}}) do
        U.kv(d,x[2],function() local st=RAVYN:GetFeatureActionStatus(x[1]); return st=="LIVE" and "LIVE" or "NEEDS BINDING",st=="LIVE" and C.green or C.gray end)
    end
end

-- ================= DIAGNOSTICS =================
function U.buildDiagnostics(page)
    local _,d=U.card(page,"Runtime","Exact internal codes.",{order=1,warn=function(S) return S.errorRecent and C.red or nil end})
    local box=U.label(d,"",11,C.sub,U.F.mono,{AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0),TextYAlignment=Enum.TextYAlignment.Top})
    U.addRefresh(function(S)
        if U.activePage~="Diagnostics" then return end
        local q=S.quest
        local lines={
            "version      "..S.version.."   fsm "..S.fsm,
            "job          "..S.job.."  P"..S.priority.."  overlay "..tostring(S.overlay),
            "owner        "..S.owner.."  reason "..S.moveReason,
            "travel       "..S.travelMode.."  tp "..S.teleports.."  tween "..S.tweens.."  noclip "..tostring(S.noclip),
            "brain        "..tostring(RAVYN.Brain and RAVYN.Brain.state).."  risk "..string.format("%.1f",S.risk).."  dps "..string.format("%.1f",S.dps).."  emergency "..tostring(S.emergency),
            "hover        "..S.hover.."  m1 "..S.m1.."  skills "..S.skills.."/"..S.skillAttempts.."  combo "..S.combo,
            "skill_fail   "..tostring(S.skillFail).."  state "..S.combatState.."  next "..S.nextAction,
            "hotbar_keys  "..(S.keySources~="" and S.keySources or "none"),
            "quest        "..q.state.."  phase "..q.phase.."  src "..tostring(q.source).."  obj "..tostring(q.objective).."  conf "..tostring(q.confidence),
            "quest_fail   "..tostring(q.fail),
            "loot         "..S.loot.state.."  "..S.loot.collected.."/"..S.loot.detected.."  unverified "..S.loot.unverified.."  fail "..tostring(S.loot.fail),
            "boss_loot    "..tostring(S.loot.boss).."  expect "..tostring(S.loot.chestExpected).."  chest "..tostring(S.loot.chest).."  via "..tostring(S.loot.chestVia),
            "chest_path   "..tostring(S.loot.chestPath),
            "handoff      session "..tostring(S.handoff.session).."  listener "..S.handoff.listener.."  by "..tostring(S.handoff.deathBy).."  handled "..tostring(S.handoff.handled).."  ctx "..S.handoff.context.."  start "..tostring(S.handoff.startCalled).." "..tostring(S.handoff.startResult).."  pending "..tostring(S.handoff.pending),
            "recovery     "..S.recovery,
            "error        "..tostring(S.error),
            "",
        }
        local GKx=RAVYN.GameKnowledge
        if GKx then
            local caps={}
            for _,k in ipairs(GKx.capOrder) do local c=GKx.capabilities[k]; if c.status~="VERIFIED" then table.insert(caps,k.."="..c.status) end end
            table.insert(lines,"caps         "..table.concat(caps," "))
        end
        for key,st in pairs(S.skillStats) do
            table.insert(lines,string.format("skill %-3s sent %d  ver %d  unv %d  cd %s  range %s-%s  %s",key,st.sent,st.verified,st.unverified,st.cooldown and string.format("%.1f",st.cooldown) or "learning",
                st.minRange and string.format("%.0f",st.minRange) or "?",st.maxRange and string.format("%.0f",st.maxRange) or "?",tostring(st.lastFail or st.lastEvidence or "")))
        end
        for _,b in ipairs(S.bosses) do
            table.insert(lines,string.format("boss %-22s %-30s %6s  chest %s%s",string.sub(tostring(b.name),1,22),b.reason,b.distance and string.format("%.0f",b.distance) or "—",tostring(b.chest or "?"),b.onlyAtNight and "  NIGHT-ONLY" or ""))
        end
        if #S.bosses==0 then table.insert(lines,"boss         none streamed") end
        U.setText(box,table.concat(lines,"\n"))
    end)
    local _,f=U.card(page,"Live feed","Bounded to the last 60 events.",{order=2})
    local feed=U.label(f,"",11,C.sub,U.F.mono,{AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0),TextYAlignment=Enum.TextYAlignment.Top})
    U.addRefresh(function()
        if U.activePage~="Diagnostics" then return end
        local fe=(RAVYN.AutoPlay384 and RAVYN.AutoPlay384.feed) or {}; local out={}
        for i=#fe,math.max(1,#fe-15),-1 do table.insert(out,fe[i].clock.."  "..fe[i].text) end
        U.setText(feed,#out>0 and table.concat(out,"\n") or "No events yet")
    end)
    local _,l=U.card(page,"Log","",{order=3,collapsible=true,collapsed=true})
    local log=U.label(l,"",10,C.faint,U.F.mono,{AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0),TextYAlignment=Enum.TextYAlignment.Top})
    U.addRefresh(function()
        if U.activePage~="Diagnostics" then return end
        local e=RAVYN.Logger.entries; local out={}
        for i=math.max(1,#e-16),#e do table.insert(out,e[i].level.."  "..e[i].message) end
        U.setText(log,table.concat(out,"\n"))
    end)
    local _,t=U.card(page,"Tools","",{order=4,collapsible=true,collapsed=true})
    U.button(t,"Run live read scan",function() return RAVYN:RunLiveReadScan() end,"accent")
    U.button(t,"Save runtime report",function() return RAVYN:SaveRuntimeReport() end)
    U.button(t,"Copy binding report",function() return RAVYN:CopyProbeReport("Binding") end)
    U.button(t,"Copy loot probe",function() return RAVYN:CopyLootProbe() end)
    U.button(t,"Copy QuestProbe report",function() return RAVYN:CopyQuestProbeReport() end)
end

-- ================= SETTINGS =================
function U.buildSettings(page)
    local _,dv=U.card(page,"Advanced","Research, diagnostics, raw settings and the capability matrix. Normal use never needs them.",{order=0})
    U.toggle(dv,{label="Developer mode",desc="Show technical pages and details",get=function() return cfg().UI.DeveloperMode end,
        set=function(v) local r=RAVYN:SetConfig("UI.DeveloperMode",v); if r and r.ok then task.defer(U.applyDevMode) end; return r end})
    local _,i=U.card(page,"Interface","",{order=1})
    U.toggle(i,{label="Remember settings",desc="Saved locally through executor file APIs",get=function() return cfg().UI.RememberSettings end,set=setc("UI.RememberSettings")})
    U.toggle(i,{label="Reduce motion",desc="Instant state changes, no tweens",get=function() return cfg().UI.ReducedMotion end,set=setc("UI.ReducedMotion")})
    U.button(i,"Save now",function() return RAVYN:SaveSettings() end,"accent")
    U.button(i,"Reload saved settings",function() return RAVYN:LoadSettings() end)
    U.button(i,"Delete saved settings",function() return RAVYN:DeleteSavedSettings() end,"danger")
    local _,w=U.card(page,"World","",{order=2})
    U.segment(w,{{"Walk",16},{"Swift",22},{"Fast",28}},function() local v=cfg().Movement.Speed; if v<=17 then return 16 elseif v<=23 then return 22 end; return 28 end,
        function(v) local r=RAVYN:SetConfig("Movement.Speed",v); if r.ok then RAVYN:SetConfig("Movement.SpeedEnabled",v~=16) end; return r end)
    U.toggle(w,{label="Mob ESP",desc="More layers on the Visuals page",get=function() return cfg().Visuals and cfg().Visuals.Mobs end,set=function(v) return RAVYN:SetVisual("Mobs",v) end})
    U.toggle(w,{label="Boss ESP",get=function() return cfg().Visuals and cfg().Visuals.Bosses end,set=function(v) return RAVYN:SetVisual("Bosses",v) end})
    U.toggle(w,{label="Anti-AFK",get=function() return cfg().Intelligence.AntiAFK end,set=function(v) return RAVYN:SetAntiAFK(v) end})
    local _,kb=U.card(page,"Keyboard shortcuts","",{order=3})
    local shortcuts={{"Ctrl + K","Open command palette"},{"/ (slash)","Open command palette"},{"Right Ctrl","Toggle hide / show"},{"Type in sidebar","Filter page list"}}
    for _,s in ipairs(shortcuts) do
        local row=U.n("Frame",kb,{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1})
        local badge=U.n("TextButton",row,{Size=UDim2.fromOffset(86,22),Position=UDim2.fromOffset(0,3),BackgroundColor3=C.card,Text=s[1],TextColor3=C.sub,TextSize=11,Font=U.F.mono,AutoButtonColor=false,BorderSizePixel=0}); U.round(badge,6); U.stroke(badge,C.line,1,.3)
        U.label(row,s[2],12,C.sub,U.F.body,{Size=UDim2.new(1,-96,1,0),Position=UDim2.fromOffset(96,0),TextWrapped=false})
    end
end
return true]==========]); if not ok then return end end
do local ok=runChunk("UI384_PagesC.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local RAVYN=CTX["RAVYN"]
local result=CTX["result"]
local U=CTX["UI384"]
local C=U.C
-- v3.8.5 Research page: Learn Action probes + GameKnowledge. Presentation only.
local function statusColor(s) return (s=="VERIFIED" and C.green) or (s=="PARTIAL" and C.orange) or (s=="DISABLED" and C.gray) or C.faint end
function U.buildResearch(page)
    local PR=RAVYN.Probe; local GK=RAVYN.GameKnowledge
    -- deep link from other pages (e.g. Quests → Research Crow)
    function U.openResearch() if U.show then U.show("Research") end end
    -- v3.9.1 UniversalTrace: one button replaces the per-system presets
    local TR=RAVYN.Trace; local FR=RAVYN.FeatureRegistry
    local _,la=U.card(page,"Learning","Press Start, play normally (accept a quest, open a menu, train, loot…), then Stop. RAVYN groups every action with what it changed and proposes candidate meanings. Nothing becomes verified automatically.",{order=1})
    local rec=U.button(la,"START LEARNING",function()
        if TR and TR.active then return RAVYN:StopLearning() end
        return RAVYN:StartLearning()
    end,"accent")
    U.addRefresh(function()
        if TR and TR.active then U.setText(rec,string.format("STOP LEARNING · %ds · %d events",math.floor(os.clock()-TR.startedAt),#TR.events)); U.setColor(rec,"TextColor3",C.red)
        else U.setText(rec,"START LEARNING"); U.setColor(rec,"TextColor3",C.gold) end
    end)
    U.kv(la,"Last trace",function() if not (TR and TR.last) then return "none yet",C.gray end
        return string.format("%d events · %d actions · %d candidates%s",#TR.events,#TR.groups,#TR.candidates,TR.saved and " · saved to RAVYN/Traces" or ""),C.green end)
    U.kv(la,"Top candidate",function() local c=TR and TR.candidates and TR.candidates[1]; if not c then return "—",C.gray end; return "["..c.confidence.."] "..c.text,C.text end)
    U.button(la,"Copy trace report",function() return RAVYN:CopyTraceReport() end)
    -- Feature registry: DATA / ACTION / VERIFY
    local _,fr=U.card(page,"Features","Identity · Presence · Action · Verify, kept separate. Presence is what is streamed now; it never lowers identity.",{order=2})
    local short={VERIFIED="✓",CANDIDATE="?",PARTIAL="~",UNRESOLVED="✗",NOT_FOUND_IN_CONTEXT="–",LOCAL="L",["N/A"]="·",PRESENT="●",NOT_STREAMED="○",NOT_CHECKED="…"}
    local function col(st) return (st=="VERIFIED" and C.green) or (st=="CANDIDATE" and C.gold) or (st=="PARTIAL" and C.orange) or (st=="LOCAL" and C.cyan) or C.faint end
    for _,k in ipairs(FR and FR.order or {}) do
        U.kv(fr,FR.features[k].title,function()
            local f=FR.features[k]
            local worst=(f.action=="UNRESOLVED" or f.action=="NOT_FOUND_IN_CONTEXT") and f.action or f.verify
            return string.format("I %s  ·  P %s  ·  A %s  ·  V %s",short[f.identity] or "?",short[f.presence] or "?",short[f.action] or "?",short[f.verify] or "?"),(f.identity=="VERIFIED" and col(worst)) or col(f.identity)
        end)
    end
    U.label(fr,"✓ verified · ? candidate · ~ partial · ✗ unresolved · – not found here · L local · ● present · ○ not streamed · … not checked",11,C.sub,U.F.body)
    U.button(fr,"Refresh runtime schema",function() if FR then FR.refresh(true) end; return RAVYN:GetRuntimeSchemaReport() end,"accent")
    U.button(fr,"Copy discovery report",function() return RAVYN:CopyDiscoveryReport() end)
    -- Capabilities (same provider as Auto Play / Quests / Diagnostics)
    local _,cp=U.card(page,"Capabilities","Single source of truth. Raised to VERIFIED only by live evidence.",{order=3,collapsible=true,collapsed=true})
    for _,k in ipairs(GK and GK.capOrder or {}) do U.capRow(cp,k) end
    -- Game systems
    local _,gs=U.card(page,"Game systems","What RAVYN understands about each Slayers 2 activity. REFERENCE facts come from guides and are never used as bindings.",{order=4,collapsible=true,collapsed=true})
    for _,k in ipairs(GK and GK.order or {}) do
        U.kv(gs,GK.systems[k].title,function()
            local s=GK.systems[k]; return s.status..(s.evidence>0 and ("  ·  "..s.evidence.." evidence") or ""),statusColor(s.status) end)
    end
    -- Player progress + world
    local _,pp=U.card(page,"Player progress","Verified reads only. Unknown values stay unresolved; possible data fields are listed as candidates.",{order=5,collapsible=true,collapsed=true})
    local lastRead=-math.huge
    U.kv(pp,"Level",function() local now=os.clock(); if now-lastRead>2 and GK then GK.readProgress(); GK.readWorld(); lastRead=now end
        local P=GK and GK.progress or {}; return P.level and tostring(P.level) or "UNRESOLVED",P.level and C.green or C.gray end)
    U.kv(pp,"EXP",function() local P=GK and GK.progress or {}; if P.exp then return tostring(P.exp).." / "..tostring(P.expRequired or "?"),C.green end; return "UNRESOLVED",C.gray end)
    U.kv(pp,"Wen · race · breathing",function() return "UNRESOLVED",C.gray end)
    U.kv(pp,"Candidate fields",function() local P=GK and GK.progress or {}; local n=P.candidates and #P.candidates or 0; return n>0 and (n.." found · see report") or "none",n>0 and C.orange or C.gray end)
    U.kv(pp,"World condition",function() local W=GK and GK.world or {}; return tostring(W.state).."  ·  "..tostring(W.candidate or ""),C.sub end)
    U.kv(pp,"Quest markers",function() local n=GK and #GK.markers or 0; return tostring(n).." seen",n>0 and C.cyan or C.gray end)
    U.button(pp,"Copy research report",function() return RAVYN:CopyResearchReport() end,"accent")
end
return true]==========]); if not ok then return end end
do local ok=runChunk("UI11_Pages.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local result=CTX["result"]
local U=CTX["UI384"]
local C=U.C
-- RAVYN DIRECT v1.1 · pages for the exploit core. Same primitives, same motion, FontScale 1.34 unchanged.
local function cfg() return RAVYN.Config end
local function setc(path) return function(v) return RAVYN:SetConfig(path,v) end end

-- ================= shared state vocabulary =================
local STATE_COLOR={OFF=C.gray,READY=C.sub,SEARCHING=C.cyan,TRAVELING=C.cyan,FIGHTING=C.green,LOOTING=C.gold,COOLDOWN=C.orange,
    UNAVAILABLE=C.red,PARTIAL=C.orange,UNVERIFIED=C.orange,COMPLETE=C.green}
function U.stateColor(s) return STATE_COLOR[s] or C.sub end
local function stateText(s,detail) if detail and detail~="" then return s.."  ·  "..detail end; return s end
-- Crow controller status → common vocabulary
function U.crowState()
    local CD=RAVYN.CrowDirect; if not CD then return "UNAVAILABLE","Crow controller missing" end
    local on=cfg().CrowDirect and cfg().CrowDirect.Enabled
    local GO=RAVYN.GoState; local goOn=GO and GO.active and not GO.paused and (GO.goal=="AUTO_PROGRESS" or GO.goal=="QUESTS")
    if not on and not goOn then return "OFF","" end
    local s=CD.status
    local map={ACTIVE=nil,COOLDOWN="COOLDOWN",DAILY_COMPLETE="COOLDOWN",NO_HUNT_AVAILABLE="COOLDOWN",OPENING_CROW="SEARCHING",READING_HUNTS="SEARCHING",
        ACCEPTING="SEARCHING",VERIFYING_ACCEPT="SEARCHING",TARGET_UNRESOLVED="SEARCHING",WAITING_LOOT="LOOTING",WAITING_COMBAT="FIGHTING",
        CROW_TOOL_NOT_FOUND="UNAVAILABLE",OPEN_FAILED="UNAVAILABLE",ACCEPT_FAILED="UNAVAILABLE",READY="READY",STOPPED="READY"}
    if s=="ACTIVE" then
        local D=RAVYN.Direct; local st=(D and D.objective and D.state) or "FIGHTING"
        return st,CD.detail or ""
    end
    if s=="DAILY_COMPLETE" then return "COOLDOWN","Daily missions complete" end
    return map[s] or "SEARCHING",CD.detail or ""
end
function U.featureStates()
    local D=RAVYN.Direct or {}; local BC=RAVYN.BossController or {}; local MZ=RAVYN.MuzanController or {}; local TC=RAVYN.TrainingController or {}
    local V=RAVYN.Visuals or {}; local LC=RAVYN.LootController or {}
    local lootOn=cfg().Loot384 and cfg().Loot384.AutoLootAfterKill
    return {
        {"Objective",D.state or "OFF",D.detail},
        {"Crow hunts",U.crowState()},
        {"Boss farm",BC.state or "OFF",BC.detail},
        {"Auto loot",(LC.active and "LOOTING") or (lootOn and "READY" or "OFF"),LC.active and LC.state or (LC.lastResult~="—" and LC.lastResult or "")},
        {"Muzan",MZ.state or "OFF",MZ.detail},
        {"Training",TC.state or "READY",TC.detail},
        {"Dungeon","UNAVAILABLE","Ouwigahara actions not mapped yet"},
        {"Visuals",V.state or "OFF",V.count and V.count>0 and (V.count.." tracked") or ""},
        {"Combat input",U.combatInputState()},
    }
end
-- v1.2.2: one line for the combat input engine (mode + whether an attack can actually execute)
function U.combatInputState()
    local Bx=RAVYN.CombatActionBus; if not Bx then return "UNAVAILABLE","combat bus missing" end
    local m=Bx.mode(); local SAx=RAVYN.SilentActionAdapter
    local atk=SAx and SAx.capStatus("ATTACK") or "UNAVAILABLE"
    if m=="SILENT" then
        if atk=="VERIFIED_SILENT" then return "READY","SILENT · attack verified" end
        return "PARTIAL","SILENT · no verified attack · nothing executes until verified"
    end
    if m=="HYBRID" then return "PARTIAL","HYBRID · silent first, labelled legacy input for the rest" end
    return "UNVERIFIED","LEGACY_INPUT · key / mouse simulation"
end
local function stateRow(parent,title,fn)
    return U.kv(parent,title,function(S) local s,d=fn(S); return stateText(s,d),U.stateColor(s) end,{size=13})
end
U.stateRow=stateRow

-- ================= HOME: systems overview =================
local baseHome=U.buildHome
function U.buildHome(page)
    baseHome(page)
    local _,sys=U.card(page,"Systems","Each feature reports what it is doing right now.",{order=5,collapsible=true})
    for i=1,9 do
        stateRow(sys,({"Objective","Crow hunts","Boss farm","Auto loot","Muzan","Training","Dungeon","Visuals","Combat input"})[i],function()
            local row=U.featureStates()[i]; return row[2],row[3] end)
    end
end

-- ================= BOSS =================
function U.buildBoss(page)
    local BC=RAVYN.BossController
    local bf=function() return cfg().BossFarm end
    local _,b=U.card(page,"Boss farm","Pick bosses, RAVYN teleports, fights, loots the chest, then moves to the next one.",{order=0,
        warn=function() return (BC and BC.state=="UNAVAILABLE") and C.orange or nil end})
    U.toggle(b,{label="Boss farm",desc="Direct teleport → Combat Hover → loot → next boss",get=function() return bf().Enabled end,set=function(v) return RAVYN:SetBossFarm(v) end,
        status=function() local s=BC and BC.state or "OFF"; return s,U.stateColor(s) end})
    U.toggle(b,{label="Rotation",desc="Cycle your selection in order after each kill",get=function() return bf().Rotation end,set=setc("BossFarm.Rotation")})
    U.toggle(b,{label="Skip respawning bosses",desc="A boss killed in the last 45 s is skipped",get=function() return bf().SkipRespawning end,set=setc("BossFarm.SkipRespawning")})
    U.toggle(b,{label="Travel to remembered bosses",desc="Teleport to a selected boss's last seen spot when it is not streamed",get=function() return bf().TravelToRemembered end,set=setc("BossFarm.TravelToRemembered")})
    U.kv(b,"Current boss",function()
        if not (BC and BC.choice) then return (BC and BC.detail~="" and BC.detail) or "—",C.gray end
        for _,x in ipairs(BC.list) do if x.name==BC.choice.name then
            return "◆ "..x.name..(x.hpPct and string.format("  ·  %d%%",math.floor(x.hpPct+.5)) or "")..(x.distance and string.format("  ·  %.0f studs",x.distance) or ""),C.gold end end
        return "◆ "..BC.choice.name,C.gold end,{size=14})
    U.bar(b,function() if BC and BC.choice then for _,x in ipairs(BC.list) do if x.name==BC.choice.name and x.hpPct then return x.hpPct/100,U.hpColor(x.hpPct) end end end; return 0,C.gray end,8)
    U.kv(b,"Chest",function() if not (BC and BC.choice) then return "—",C.gray end
        for _,x in ipairs(BC.list) do if x.name==BC.choice.name then return (x.chest or "unknown")..(x.onlyAtNight and "  ·  night only" or ""),x.chest and C.text or C.gray end end
        return "—",C.gray end)
    U.kv(b,"Bosses defeated",function() return tostring(BC and BC.kills or 0).." this session",C.sub end)
    U.kv(b,"After death",function() local r=BC and BC.lastRespawn; if not r then return cfg().TravelController.ReturnToBossOnRespawn and "Return to the same boss" or "Off",C.sub end
        return tostring(r.result).."  ·  "..tostring(r.boss or ""),(r.result=="TELEPORTED" or r.result=="SENT") and C.green or C.sub end)
    local _,l=U.card(page,"Bosses","Tap to select. No selection = nearest eligible boss. Selected bosses rotate in the order you pick them.",{order=1})
    local rows={}
    for i=1,12 do
        local r=U.n("TextButton",l,{Size=UDim2.new(1,0,0,40),BackgroundColor3=C.card,Text="",AutoButtonColor=false,BorderSizePixel=0,Visible=false}); U.round(r,10)
        local mark=U.label(r,"",14,C.gold,U.F.bold,{Size=UDim2.fromOffset(26,40),Position=UDim2.fromOffset(12,0),TextWrapped=false})
        local nm=U.label(r,"",13,C.text,U.F.semi,{Size=UDim2.new(1,-300,1,0),Position=UDim2.fromOffset(40,0),TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd})
        local st=U.label(r,"",11,C.sub,U.F.bold,{Size=UDim2.fromOffset(250,40),Position=UDim2.new(1,-262,0,0),TextXAlignment=Enum.TextXAlignment.Right,TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd})
        U.pressable(r,{hoverScale=1.006,pressScale=.985,enterColor=C.raised,leaveColor=C.card})
        table.insert(RAVYN._connections,r.Activated:Connect(function()
            local name=r:GetAttribute("boss"); if not name then return end
            U.report(RAVYN:ToggleBossSelected(name),name)
        end))
        rows[i]={r=r,mark=mark,nm=nm,st=st}
    end
    local empty=U.label(l,"No boss seen yet · bosses appear here once streamed or known from Boss Hunts",12,C.sub,U.F.body)
    U.addRefresh(function()
        local list=(BC and BC.list) or {}
        empty.Visible=#list==0
        for i,row in ipairs(rows) do
            local x=list[i]; row.r.Visible=x~=nil
            if x then
                row.r:SetAttribute("boss",x.name)
                U.setText(row.mark,x.selected and "✓" or "·"); U.setColor(row.mark,"TextColor3",x.selected and C.gold or C.faint)
                U.setText(row.nm,x.name..(x.onlyAtNight and "  ☾" or ""))
                local stTxt=(x.status=="ALIVE" and ((x.hpPct and string.format("ALIVE · %d%%",math.floor(x.hpPct+.5)) or "ALIVE")..(x.distance and string.format(" · %.0f studs",x.distance) or "")))
                    or (x.status=="SKIPPED" and ("SKIPPED · "..tostring(x.reason))) or (x.status=="NOT_STREAMED" and "NOT STREAMED · last spot known")
                    or (x.status=="UNKNOWN_LOCATION" and "NOT STREAMED") or (x.status=="RESPAWNING" and "RESPAWNING") or (x.status=="UNAVAILABLE" and "UNAVAILABLE") or x.status
                U.setText(row.st,stTxt)
                U.setColor(row.st,"TextColor3",(x.status=="ALIVE" and C.green) or (x.status=="RESPAWNING" and C.orange) or ((x.status=="SKIPPED" or x.status=="UNAVAILABLE") and C.red) or C.faint)
            end
        end
    end)
    U.button(l,"Clear selection",function() return RAVYN:ClearBossSelection() end)
    if U.buildFarm then U.buildFarm(page) end
end

-- ================= QUESTS: objective + Muzan =================
local baseQuests=U.buildQuests
function U.buildQuests(page)
    local D=RAVYN.Direct
    local _,o=U.card(page,"Objective","Read from your own quest data. RAVYN teleports to the target, fights it, loots, then takes the next one.",{order=-1})
    stateRow(o,"Status",function() return D and D.state or "OFF",D and D.detail end)
    U.kv(o,"Target",function() local ob=D and D.objective; if not ob then return "—",C.gray end
        return ob.name..(ob.boss and "  ◆" or ""),ob.streamed and C.text or C.cyan end,{size=14})
    U.kv(o,"Source",function() local ob=D and D.objective; return ob and ob.source or "—",ob and C.purple or C.gray end)
    U.kv(o,"Progress",function() local ob=D and D.objective; if ob and ob.progress then return string.format("%d / %d",ob.progress,ob.required or 0),C.purple end; return "—",C.gray end)
    U.bar(o,function() local ob=D and D.objective; if ob and ob.progress and ob.required and ob.required>0 then return ob.progress/ob.required,C.purple end; return 0,C.purple end)
    U.kv(o,"Quest data",function() if not D then return "—",C.gray end
        if D.questError then return "Unavailable · "..tostring(D.questError),C.orange end
        return tostring(#D.quests).." active",C.sub end)
    U.toggle(o,{label="Follow quest objective",desc="Active quest target drives targeting during Auto Play",get=function() return cfg().Direct.FollowQuestData end,set=setc("Direct.FollowQuestData")})
    baseQuests(page)
    local MZ=RAVYN.MuzanController
    local mz=function() return cfg().MuzanDirect end
    local _,m=U.card(page,"Muzan","Find → teleport → open dialogue → fight the task target. Task selection is not mapped yet, so you choose it.",{order=4})
    U.toggle(m,{label="Muzan",desc="Track Muzan and handle his task objectives",get=function() return mz().Enabled end,set=function(v) return RAVYN:SetMuzan("Enabled",v) end,
        status=function() local s=MZ and MZ.state or "OFF"; return s,U.stateColor(s) end})
    U.toggle(m,{label="Auto open dialogue",desc="Fires Muzan's own prompt once, verified by his dialogue appearing",get=function() return mz().AutoInteract end,set=function(v) return RAVYN:SetMuzan("AutoInteract",v) end,
        dep=function() return mz().Enabled end,depText="Enable Muzan first"})
    U.kv(m,"Now",function() return (MZ and MZ.detail~="" and MZ.detail) or "—",C.sub end)
    for _,x in ipairs({{"find","Find Muzan"},{"teleport","Teleport"},{"interact","Open dialogue"},{"accept","Choose task"},{"objective","Task objective"},{"repeatTask","Repeat"}}) do
        stateRow(m,x[2],function() local s=MZ and MZ.sub[x[1]] or "UNAVAILABLE"
            local why=(s=="UNAVAILABLE" and (x[1]=="accept" or x[1]=="repeatTask")) and "needs a verified task-menu binding" or ((s=="PARTIAL") and "works, verification limited" or "")
            return s,why end)
    end
    local dl=U.label(m,"",11,C.sub,U.F.body,{AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0)})
    U.addRefresh(function() local t=MZ and MZ.dialogue or {}; dl.Visible=#t>0; if #t>0 then U.setText(dl,"Dialogue: "..table.concat(t,"  ·  ")) end end)
    U.button(m,"Teleport to Muzan",function() return RAVYN:TeleportToMuzan() end,"accent")
end

-- ================= TRAINING =================
function U.buildTraining(page)
    local TC=RAVYN.TrainingController
    local _,b=U.card(page,"Breathing","Your style is read from your hotbar and your own player data — never assumed.",{order=1})
    local detectAt=-math.huge
    U.kv(b,"Detected style",function()
        local now=os.clock(); if now-detectAt>5 then detectAt=now; pcall(TC.detect) end
        return TC.detected and (TC.detected.." Breathing") or "Not visible",TC.detected and C.gold or C.gray end,{size=14})
    U.kv(b,"Detected from",function() return tostring(TC.detectedFrom or "—"),C.sub end)
    U.label(b,"Trainer",12,C.sub,U.F.semi)
    local T=TC.TRAINERS
    U.segment(b,{T[1],T[2],T[3],T[4]},function() return cfg().TrainingDirect.SelectedStyle end,function(v) return RAVYN:SetTrainingStyle(v) end)
    U.segment(b,{T[5],T[6],T[7],T[8]},function() return cfg().TrainingDirect.SelectedStyle end,function(v) return RAVYN:SetTrainingStyle(v) end)
    U.kv(b,"Trainer location",function()
        local st=cfg().TrainingDirect.SelectedStyle; if st=="" then return "Pick a trainer",C.gray end
        local rec=TC.trainers[st]
        if not TC.scannedAt then return "Not scanned yet",C.gray end
        if rec and rec.pos then return "Streamed",C.green end
        if rec and rec.identity then return "Known · not streamed here",C.orange end
        return "Not found",C.red end)
    stateRow(b,"Status",function() return TC.state or "READY",TC.detail end)
    U.button(b,"Teleport to trainer",function() return RAVYN:TeleportToTrainer() end,"accent")
    U.button(b,"Scan trainers & stations",function() TC.scan(); return result(true,"SCANNED") end)
    local _,s=U.card(page,"Stations","Workspace training stations and their prompts. You play the minigame; RAVYN takes you there and can start it.",{order=2})
    local rows={}
    for i=1,8 do
        local r=U.n("Frame",s,{Size=UDim2.new(1,0,0,40),BackgroundColor3=C.card,BorderSizePixel=0,Visible=false}); U.round(r,10)
        local nm=U.label(r,"",13,C.text,U.F.semi,{Size=UDim2.new(1,-220,1,0),Position=UDim2.fromOffset(12,0),TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd})
        local go=U.n("TextButton",r,{Size=UDim2.fromOffset(92,30),Position=UDim2.new(1,-200,.5,-15),BackgroundColor3=C.raised,Text="Go",TextColor3=C.text,TextSize=12,Font=U.F.semi,AutoButtonColor=false,BorderSizePixel=0}); U.round(go,8)
        local start=U.n("TextButton",r,{Size=UDim2.fromOffset(92,30),Position=UDim2.new(1,-100,.5,-15),BackgroundColor3=C.goldDim,Text="Start",TextColor3=C.gold,TextSize=12,Font=U.F.semi,AutoButtonColor=false,BorderSizePixel=0}); U.round(start,8)
        U.pressable(go,{hoverScale=1.03,pressScale=.95}); U.pressable(start,{hoverScale=1.03,pressScale=.95})
        table.insert(RAVYN._connections,go.Activated:Connect(function() U.report(RAVYN:TeleportToStation(i),"Station") end))
        table.insert(RAVYN._connections,start.Activated:Connect(function() U.report(RAVYN:InteractTrainingStation(i),"Station started") end))
        rows[i]={r=r,nm=nm,start=start}
    end
    local none=U.label(s,"Press Scan to list stations",12,C.sub,U.F.body)
    U.addRefresh(function()
        if not TC.scannedAt then pcall(TC.scan) end
        local list=TC.stations or {}
        none.Visible=#list==0; if #list==0 and TC.scannedAt then U.setText(none,"No Workspace.Training stations streamed here") end
        for i,row in ipairs(rows) do
            local x=list[i]; row.r.Visible=x~=nil
            if x then U.setText(row.nm,x.name..(x.action and ("  ·  "..x.action) or "")); row.start.Visible=x.prompt~=nil end
        end
    end)
    local _,sa=U.card(page,"Sub-actions","",{order=3})
    for _,x in ipairs({{"select","Trainer selection","ready"},{"teleport","Trainer / station teleport","direct teleport"},{"interact","Start station","fires its prompt once"},
        {"minigame","Minigame","no verified input logic"},{"progress","Progress","local quest data"}}) do
        stateRow(sa,x[2],function() return TC.sub[x[1]] or "UNAVAILABLE",x[3] end)
    end
    local _,p=U.card(page,"Progress","Your local quest data and mastery entries.",{order=4,collapsible=true})
    local ql=U.label(p,"",12,C.sub,U.F.body,{AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0)})
    local ml=U.label(p,"",11,C.faint,U.F.mono,{AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0)})
    U.addRefresh(function()
        local D=RAVYN.Direct; local lines={}
        for _,q in ipairs((D and D.quests) or {}) do table.insert(lines,q.quest..(q.progress and string.format("  ·  %d/%d",q.progress,q.required or 0) or "")) end
        U.setText(ql,#lines>0 and table.concat(lines,"\n") or "No active quest")
        local m=TC.readMastery(); local ml2={}
        if m and m.rows then for i,r in ipairs(m.rows) do if i>8 then break end; table.insert(ml2,r.name.."  "..r.value) end end
        U.setText(ml,(#ml2>0 and ("Mastery\n"..table.concat(ml2,"\n"))) or ((m and m.error) and ("Mastery: "..tostring(m.error))) or "Mastery: no entries")
    end)
end

-- ================= DUNGEON =================
function U.buildDungeon(page)
    local DG=RAVYN.DungeonController; local R=DG.reader or {}
    local _,m=U.card(page,"Dungeon mode","Reads the Ouwigahara HUD once found: Floor, Points, Enemies remaining, Rerolls and the card choice.",{order=0})
    U.toggle(m,{label="Dungeon mode",desc="Search your screen once for the dungeon HUD, then read only that",get=function() return cfg().Ouwi11.Enabled end,set=function(v) return RAVYN:SetDungeonMode(v) end,
        status=function() local s=R.status or "OFF"; return s,U.stateColor(s) end})
    U.kv(m,"HUD",function() return R.rootPath and "Found" or (cfg().Ouwi11.Enabled and "Searching…" or "—"),R.rootPath and C.green or C.gray end)
    U.kv(m,"Floor",function() return R.floor and tostring(R.floor) or (R.hits and R.hits.floor) or "—",R.floor and C.text or C.gray end,{size=14})
    U.kv(m,"Points",function() return R.points and tostring(R.points) or (R.hits and R.hits.points) or "—",R.points and C.gold or C.gray end)
    U.kv(m,"Enemies remaining",function() return R.enemies and tostring(R.enemies) or (R.hits and R.hits.enemies) or "—",R.enemies and C.text or C.gray end)
    U.kv(m,"Rerolls",function() return R.rerolls and tostring(R.rerolls) or (R.hits and R.hits.rerolls) or "—",R.rerolls and C.text or C.gray end)
    U.kv(m,"Run state",function() if not cfg().Ouwi11.Enabled then return "OFF",C.gray end; return R.rootPath and "IN RUN (HUD visible)" or "NOT DETECTED",R.rootPath and C.green or C.gray end)
    local cl=U.label(m,"",11,C.sub,U.F.mono,{AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0)})
    U.addRefresh(function()
        local rk=R.ranked or {}
        cl.Visible=#rk>0
        if #rk>0 then local lines={"Cards on screen (ranked):"}; for i,x in ipairs(rk) do table.insert(lines,string.format("%d  %-18s %s",i,x.name,x.score==-math.huge and "BLACKLISTED" or x.reason)) end; U.setText(cl,table.concat(lines,"\n")) end
    end)
    U.kv(m,"Last card picked",function() return R.lastPick or "—",R.lastPick and C.green or C.gray end)
    U.button(m,"Re-scan for dungeon HUD",function() return RAVYN:RediscoverDungeonHud() end)
    local _,d=U.card(page,"Ouwigahara automation","Steps without a verified game action stay locked instead of pretending.",{order=1})
    for _,s in ipairs(DG.sub) do
        U.toggle(d,{label=s.label,desc=s.why,get=function() return cfg().Ouwi11[s.key] end,set=function(v) return RAVYN:SetDungeonOption(s.key,v) end,
            dep=function() return s.status~="UNAVAILABLE" and s.status~="UNVERIFIED" end,depText=s.label.." needs a verified game action first",
            status=function() local st=DG.status(s.key); if s.status=="UNVERIFIED" then st="UNVERIFIED" end; return st,U.stateColor(st) end})
    end
    local _,c=U.card(page,"Card preferences","The ranking engine applies these to whatever cards the reader finds.",{order=3})
    local dc=function() return cfg().Dungeon end
    U.kv(c,"Blacklist",function() return table.concat(dc().Blacklist or {},", "),C.red end)
    U.kv(c,"Priority",function() return table.concat(dc().PriorityOrder or {},", "),C.green end)
    U.kv(c,"Low priority",function() return table.concat(dc().LowPriority or {},", "),C.orange end)
end

-- ================= LOOT: boss loot V2 =================
local baseLoot=U.buildLoot
function U.buildLoot(page)
    baseLoot(page)
    local B=RAVYN.BossLootV2
    local _,b=U.card(page,"Boss chest & drops","Boss dies → chest prompt → its key → drops → each drop's key → verified by your chest counter and inventory.",{order=0})
    U.toggle(b,{label="Boss loot V2",desc="Uses the key the game's own prompt shows (T)",get=function() return cfg().BossLootV2.Enabled end,set=setc("BossLootV2.Enabled"),
        status=function(S) local st=(S.loot.active and RAVYN.LootController.v2Active) and "LOOTING" or (cfg().BossLootV2.Enabled and "READY" or "OFF"); return st,U.stateColor(st) end})
    U.kv(b,"Step",function() return B and B.phase or "IDLE",(B and B.phase~="IDLE") and C.gold or C.gray end)
    U.kv(b,"Chests opened",function() local c=B and B.chestsCounter and B.chestsCounter(); return tostring(B and B.stats.chestsOpened or 0).." this session"..(c and ("  ·  total "..c) or ""),C.sub end)
    U.kv(b,"Verified by",function() return tostring(B and B.verifiedBy or "—"),C.sub end)
    U.kv(b,"Items collected",function() return tostring(B and B.stats.items or 0)..((B and B.stats.unverified>0) and ("  ·  "..B.stats.unverified.." unverified") or ""),C.green end)
    U.kv(b,"Last loot",function() local l=B and B.lastItems or {}; return #l>0 and table.concat(l,", ") or "—",#l>0 and C.text or C.gray end)
end

-- ================= COMBAT: Input engine (v1.2.2 silent combat) + Insta Kill (hardened) =================
U.MSG.FINISHER_LOCK={"Finisher","Normal combat paused for one finishing action and its verification.","gold"}
U.MSG.SILENT_UNAVAILABLE={"Silent action unavailable","SILENT mode: this action has no verified local game action. Nothing is sent. Verify silent bindings, or use HYBRID.","orange"}
U.MSG.THRESHOLD_FINISHER_SILENT_UNAVAILABLE={"Silent finisher unavailable","No verified local attack/skill action for the finisher. Normal combat continues.","orange"}
U.MSG.SILENT_VERIFY_RUNNING={"Verifying silent bindings","Combat actions pause while each local action is tested once.","cyan"}
U.MSG.LEGACY_BLOCKED_IN_SILENT={"Legacy input blocked","SILENT mode never falls back to key or mouse simulation.","orange"}
U.MSG.PHYSICAL_INPUT_BLOCKED={"Input blocked","A combat key/click did not come through the combat bus and was blocked.","red"}
U.MSG.PLAYER_STUNNED={"Stunned","Your character cannot act right now.","gold"}
U.MSG.GUARD_HELD={"Guarding","Attacks wait until the guard is released.","gold"}
U.MSG.ACTION_FAILED={"Action failed","The local action could not be invoked; bindings are re-resolved.","orange"}
U.MSG.COMBAT_BUS_UNAVAILABLE={"Combat bus missing","The CombatActionBus did not install.","red"}
U.MSG.SKILL_NOT_READY={"Skill not ready","That skill is cooling down.","cyan"}
U.MSG.GUARD_KEY_UNRESOLVED={"Guard key unknown","No guard key is resolved for legacy input.","orange"}
local function capColor(s) return (s=="VERIFIED_SILENT" and C.green) or (s=="PARTIAL" and C.orange) or C.red end
local function capText(s) return (s=="VERIFIED_SILENT" and "VERIFIED") or tostring(s) end
local busCache,busAt=nil,-math.huge
local function bus() local B=RAVYN.CombatActionBus; if not B then return nil end; local now=os.clock(); if now-busAt>.2 then busCache=B.status(); busAt=now end; return busCache end
U.busStatus=bus
local baseCombat=U.buildCombat
function U.buildCombat(page)
    baseCombat(page)
    -- ---------- INPUT ENGINE ----------
    local _,ie=U.card(page,"Input engine","Every combat action goes through one bus. SILENT runs only actions the game itself exposes on your client and never simulates a key or a click.",{order=0,
        warn=function() local st=bus(); if not st then return C.red end; if st.mode=="SILENT" and st.physicalCombat>0 then return C.red end; if st.mode=="SILENT" and st.caps.ATTACK.status~="VERIFIED_SILENT" then return C.orange end; return nil end})
    U.segment(ie,{{"Silent","SILENT"},{"Hybrid","HYBRID"},{"Legacy input","LEGACY_INPUT"}},function() return cfg().CombatInputMode end,function(v) return RAVYN:SetCombatInputMode(v) end)
    U.kv(ie,"INPUT ENGINE",function() local m=cfg().CombatInputMode; return tostring(m),(m=="SILENT" and C.green) or (m=="HYBRID" and C.orange) or C.red end,{size=14})
    for _,cap in ipairs({{"ATTACK","Attack"},{"SKILL","Skills"},{"GUARD","Guard"},{"DASH","Dash"},{"PARRY","Parry"}}) do
        U.kv(ie,cap[2],function()
            local st=bus(); local c=st and st.caps[cap[1]]
            if not c then return "UNAVAILABLE",C.red end
            local detail=(cap[1]=="SKILL") and c.reason or (c.binding or c.reason)
            return capText(c.status).."  ·  "..tostring(detail),capColor(c.status) end)
    end
    U.kv(ie,"Current action",function()
        local st=bus(); if not st then return "—",C.gray end
        local a=st.current or st.last
        if not a then return st.testing and "Silent test running" or "—",C.gray end
        local state=st.current and "ACTION_LOCK" or (a.confirmed and "CONFIRMED" or (a.failed and "FAILED" or "UNCONFIRMED"))
        return tostring(a.label).."  ·  "..tostring(a.displayLabel or a.backend).."  ·  "..state..(a.evidence and ("  ·  "..a.evidence) or ""),
            (a.backend=="LEGACY_INPUT" and C.orange) or (state=="CONFIRMED" and C.green) or C.text end)
    U.kv(ie,"Backend",function() local st=bus(); if not st then return "—",C.gray end; return st.backend,(st.mode=="SILENT" and C.green) or C.orange end)
    U.kv(ie,"Physical inputs this fight",function()
        local st=bus(); if not st then return "—",C.gray end
        local n=st.physicalCombat
        local txt=tostring(n).." combat"..(st.physicalOther>0 and ("  ·  "..st.physicalOther.." menu/loot") or "")..(st.blocked>0 and ("  ·  "..st.blocked.." blocked") or "")
        return txt,(n>0 and st.mode=="SILENT" and C.red) or (n>0 and C.orange) or C.green end)
    U.kv(ie,"Executed",function() local st=bus(); if not st then return "—",C.gray end
        return string.format("%d silent  ·  %d legacy  ·  %d finisher",st.silentCount,st.legacyCount,st.finisherCount),C.sub end)
    U.kv(ie,"Last refusal",function() local Bx=RAVYN.CombatActionBus; local r=Bx and Bx.lastCapReject
        if not r then return "—",C.gray end
        local e=U.explain(r.code); return (e and e.title or r.code).."  ·  "..tostring(r.kind),e and e.color or C.orange end)
    U.kv(ie,"Silent test",function()
        local st=bus(); if not st then return "—",C.gray end
        if st.testing and st.test then return "Testing · "..tostring(st.test.step),C.cyan end
        local t=st.lastTest; if not t then return "Not run yet",C.gray end
        local pass,total=0,0; for _,x in ipairs(t.results or {}) do total=total+1; if x.pass then pass=pass+1 end end
        return string.format("%d/%d actions verified",pass,total),pass>0 and C.green or C.orange end)
    U.button(ie,"Verify silent bindings",function() return RAVYN:VerifySilentBindings() end,"accent")
    U.button(ie,"Re-resolve local actions",function() return RAVYN:ResolveSilentBindings() end)
    U.label(ie,"Stand next to a mob, then Verify: each local action found is triggered once through the game's own handler and becomes VERIFIED only if your character shows it (animation, damage counter, skill cooldown). SILENT never falls back to key/mouse input — if nothing is verified, nothing executes.",11,C.sub,U.F.body,{AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0)})
    -- ---------- INSTA KILL ----------
    local IK=RAVYN.InstaKillAdapter; if not IK then return end
    local ikCache,ikAt=nil,-math.huge
    local st=function() local now=os.clock(); if now-ikAt>.2 then ikCache=IK.GetStatus(); ikAt=now end; return ikCache end
    local _,k=U.card(page,"Insta Kill · Threshold 99%","Normal combat to ≤1% HP, then ONE finishing action, verified by death AND your credit. Auto uses it only after the full test matrix passes. No true one-hit path is used.",{order=2})
    U.segment(k,{{"Auto","AUTO"},{"Threshold 99% · test","THRESHOLD_99"},{"Max burst","MAX_BURST"}},function() return cfg().InstaKill.Mode end,function(v) return RAVYN:SetInstaKillMode(v) end)
    U.kv(k,"Status",function() local s=st(); local vs=s.verificationStatus
        return s.statusText,(vs=="VERIFIED" and C.green) or (vs=="FAILED" and C.red) or (vs=="PROBATION" and C.cyan) or (vs=="TESTING" and C.gold) or C.gray end,{size=14})
    U.kv(k,"In use",function() local s=st()
        if s.activeClass=="THRESHOLD_99" and not s.available then return "THRESHOLD_99 selected · no executable finisher → normal combat",C.orange end
        if s.activeClass=="THRESHOLD_99" then return "THRESHOLD_99 · finisher active"..(s.mode=="THRESHOLD_99" and s.verificationStatus~="VERIFIED" and " (testing)" or ""),C.gold end
        if s.mode=="AUTO" and s.verificationStatus=="VERIFIED" and not s.backendCompatible then return "MAX BURST · verified with "..tostring(s.verifiedBackend).." only",C.orange end
        return "MAX BURST"..(s.mode=="AUTO" and " · until VERIFIED" or ""),C.sub end)
    U.kv(k,"Finisher",function() local s=st()
        if not s.available then return tostring(s.finisherLabel),C.red end
        return tostring(s.finisherLabel)..(s.finisherBackend=="LEGACY_INPUT" and "  ·  LEGACY" or ""),(s.finisherBackend=="SILENT_LOCAL") and C.green or C.orange end)
    U.kv(k,"Now",function() local s=st(); local ph=s.phase
        if ph=="IDLE" then
            if s.activeClass=="THRESHOLD_99" and not s.available then return "Finisher unavailable · "..((cfg().CombatInputMode=="SILENT") and "no verified silent attack/skill" or "no finisher action"),C.orange end
            return (s.blockReason and (U.explain(s.blockReason) or {}).title) or ((s.activeClass=="THRESHOLD_99") and ("Watching HP · pre-arm on"..(IK.armWhy and ("  ·  "..IK.armWhy) or "")) or "—"),s.blockReason and C.orange or C.sub end
        return (ph=="ARMED" and "Finisher armed · combat paused") or "Verifying kill · nothing else sent",C.gold end)
    U.kv(k,"Streak",function() local s=st(); return string.format("%d / %d in a row",s.consecutivePassed,s.testsRequired),s.consecutivePassed>0 and C.green or C.gray end)
    U.bar(k,function() local s=st(); return s.consecutivePassed/math.max(1,s.testsRequired),(s.verificationStatus=="VERIFIED" and C.green) or C.gold end,6)
    U.kv(k,"Normal mobs",function() local s=st(); return string.format("%d / %d",s.normalMobPassed,s.required.normal),s.normalMobPassed>=s.required.normal and C.green or C.sub end)
    U.kv(k,"Bosses (different)",function() local s=st(); return string.format("%d / %d  ·  %d boss passes",s.bossDistinct,s.required.bosses,s.bossPassed),s.bossDistinct>=s.required.bosses and C.green or C.sub end)
    U.kv(k,"High-HP boss",function() local s=st(); return string.format("%d / %d  ·  MaxHealth ≥ %s",s.highHpBossPassed,s.required.highHp,tostring(s.required.highHpMin)),s.highHpBossPassed>=s.required.highHp and C.green or C.sub end)
    U.kv(k,"Results",function() local s=st()
        return string.format("lethal %d · credit %d · misses %d · invalid %d · kill-only %d",s.lethalSuccesses,s.creditSuccesses,s.misses,s.invalidVerifications,s.killOnly),
            (s.misses>0 or s.invalidVerifications>0) and C.orange or C.sub end)
    U.kv(k,"Still needed",function() local s=st(); if s.verificationStatus=="VERIFIED" then return tostring(s.verifiedMatrix),C.green end
        return (#s.missing>0) and table.concat(s.missing,", ") or "—",C.sub end)
    U.kv(k,"Last test",function() local r=st().lastTest; if not r then return "—",C.gray end
        local c=r.classification or "PENDING"
        return tostring(r.target).." · "..c..string.format(" · HP %.1f%%",(r.hpBefore or 0)*100).." · "..tostring(r.trigger),
            (c=="KILL_AND_CREDIT" and C.green) or (c=="INVALID_VERIFICATION" and C.orange) or C.red end)
    U.label(k,"High-HP boss means MaxHealth at least",12,C.sub,U.F.semi)
    U.segment(k,{{"5k",5000},{"10k",10000},{"25k",25000},{"50k",50000}},function() return cfg().InstaKill.HighHpBossMinMaxHealth end,function(v) return RAVYN:SetInstaKillHighHp(v) end)
    U.button(k,"Reset verification",function() return RAVYN:ResetInstaKillVerification() end)
end

-- ================= DIAGNOSTICS: silent combat + Insta Kill test records =================
local baseDiag=U.buildDiagnostics
function U.buildDiagnostics(page)
    baseDiag(page)
    local _,sc=U.card(page,"Silent combat","ActionResolver candidates, what is listed but never invoked, the last silent test and every physical input RAVYN made.",{order=4})
    local sbox=U.label(sc,"",11,C.sub,U.F.mono,{AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0),TextYAlignment=Enum.TextYAlignment.Top})
    U.addRefresh(function()
        if U.activePage~="Diagnostics" then return end
        local B=RAVYN.CombatActionBus; local SA=RAVYN.SilentActionAdapter; local A=RAVYN.InputAudit
        if not (B and SA and A) then U.setText(sbox,"combat bus not installed"); return end
        local st=B.status(); local lines={}
        table.insert(lines,"mode "..st.mode.."  backend "..st.backend.."  resolve#"..tostring(st.gen).." ("..tostring(st.resolveReason)..")")
        table.insert(lines,string.format("api  CAS=%s getconnections=%s firesignal=%s getrenv=%s",tostring(st.api and st.api.cas),tostring(st.api and st.api.getconnections),tostring(st.api and st.api.firesignal),tostring(st.api and st.api.getrenv)))
        for _,c in ipairs({"ATTACK","HEAVY","GUARD","DASH","PARRY"}) do
            local x=SA.caps[c]
            if x then
                table.insert(lines,string.format("%-7s %-15s %s",c,x.status,tostring(x.reason)))
                for i,b in ipairs(x.candidates) do if i>3 then break end; table.insert(lines,"        "..(b==x.binding and "▸ " or "  ")..b.label..(b.lastError and ("  ["..b.lastError.."]") or "")) end
            end
        end
        local keys={}; for key,x in pairs(SA.skills) do table.insert(keys,{key=key,x=x}) end
        table.sort(keys,function(a,b) return (a.x.index or 99)<(b.x.index or 99) end)
        for _,e in ipairs(keys) do
            local x=e.x
            table.insert(lines,string.format("SKILL %-2s %-15s %s",e.key,x.status,tostring(x.reason)))
            for i,b in ipairs(x.candidates) do if i>2 then break end; table.insert(lines,"        "..(b==x.binding and "▸ " or "  ")..b.label..(b.lastError and ("  ["..b.lastError.."]") or "")) end
        end
        if #SA.listed.cas>0 then table.insert(lines,"CAS actions: "..table.concat(SA.listed.cas,"  ",1,math.min(#SA.listed.cas,10))) end
        if #SA.listed.bindables>0 then table.insert(lines,"bindables (listed, not invoked): "..table.concat(SA.listed.bindables,"  ")) end
        if #SA.listed.controllers>0 then table.insert(lines,"controllers (listed, not invoked): "..table.concat(SA.listed.controllers,"  ")) end
        local t=st.testing and st.test or st.lastTest
        if t then
            table.insert(lines,"silent test · "..tostring(t.step))
            for _,x in ipairs(t.results or {}) do table.insert(lines,string.format("  %-9s %s  %s  %s",x.cap,x.pass and "PASS" or "no  ",tostring(x.label),tostring(x.evidence or x.error or ""))) end
        end
        table.insert(lines,string.format("fight  physical combat %d · menu/loot %d · blocked %d · executed %d (silent %d, legacy %d)",st.physicalCombat,st.physicalOther,st.blocked,
            st.fight and st.fight.executed or 0,st.fight and st.fight.silent or 0,st.fight and st.fight.legacy or 0))
        table.insert(lines,string.format("audit  total %d · non-combat %d · blocked %d · legacy adapter %d (+%d releases)",A.total,A.nonBus,A.blocked,st.legacy.count,st.legacy.releases))
        for i=#A.events,math.max(1,#A.events-7),-1 do local e=A.events[i]; table.insert(lines,string.format("  %-6s %-14s %-15s %s",e.kind,e.detail,e.scope,e.allowed and "sent" or ("BLOCKED "..tostring(e.why)))) end
        U.setText(sbox,table.concat(lines,"\n"))
    end)
    local IK=RAVYN.InstaKillAdapter; if not IK then return end
    local _,d=U.card(page,"Threshold Finisher · 99%","InstaKillAdapter + CreditProbe. Each finisher test lists everything needed to judge it.",{order=5})
    local box=U.label(d,"",11,C.sub,U.F.mono,{AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0),TextYAlignment=Enum.TextYAlignment.Top})
    U.addRefresh(function()
        if U.activePage~="Diagnostics" then return end
        local s=IK.GetStatus()
        local lines={
            "mode         "..s.mode.."  active "..s.activeClass.."  threshold "..string.format("%.0f%%",s.threshold*100).."  (stays 1%)",
            "true_one_hit "..s.trueOneHitStatus.."  (trueOneHit=false)",
            "verification "..s.statusText.."  tests "..s.testsRun.."  lethal "..s.lethalSuccesses.."  credit "..s.creditSuccesses.."  misses "..s.misses.."  invalid "..s.invalidVerifications.."  kill-only "..s.killOnly,
            "matrix       normal "..s.normalMobPassed.."/"..s.required.normal.."  bosses "..s.bossDistinct.."/"..s.required.bosses.." different  high-HP "..s.highHpBossPassed.."/"..s.required.highHp.."  streak "..s.consecutivePassed.."/"..s.testsRequired,
            "finisher     "..tostring(s.finisherLabel).."  backend "..tostring(s.finisherBackend).."  phase "..s.phase..(s.blockReason and ("  blocked "..s.blockReason) or ""),
            "not tests    died before finisher "..s.diedBeforeFinisher.."  window skipped "..s.windowSkips.."  not lethal after settle "..s.notLethal,
            s.verificationStatus=="VERIFIED" and ("verified     "..tostring(s.verifiedMatrix)) or ("needed       "..table.concat(s.missing,", ")),
            "",
        }
        local tests=IK.V.tests
        for i=#tests,math.max(1,#tests-7),-1 do local r=tests[i]; table.insert(lines,(r.text or IK.describe(r))..string.format("  · phys %s · blocked %s",tostring(r.physicalDuringVerify),tostring(r.blockedDuringVerify))) end
        if #tests==0 then table.insert(lines,"no finisher tests yet · set Insta Kill to Threshold 99% · test to run the matrix") end
        table.insert(lines,"")
        for i=#IK.records,math.max(1,#IK.records-5),-1 do local r=IK.records[i]; if not r.finisher then table.insert(lines,r.text or IK.describe(r)) end end
        U.setText(box,table.concat(lines,"\n"))
    end)
end

-- ================= VISUALS =================
function U.buildVisuals(page)
    local V=RAVYN.Visuals
    local vv=function() return cfg().Visuals end
    local sv=function(k) return function(v) return RAVYN:SetVisual(k,v) end end
    local _,e=U.card(page,"ESP","Pooled labels · no per-frame rebuild · other players are not tracked.",{order=1})
    U.toggle(e,{label="Mobs",get=function() return vv().Mobs end,set=sv("Mobs")})
    U.toggle(e,{label="Bosses",desc="Label + highlight",get=function() return vv().Bosses end,set=sv("Bosses")})
    U.toggle(e,{label="Quest target",desc="The current objective target",get=function() return vv().QuestTarget end,set=sv("QuestTarget")})
    U.toggle(e,{label="Chests",desc="Nearby chest prompts (bounded scan)",get=function() return vv().Chests end,set=sv("Chests")})
    U.toggle(e,{label="Drops",desc="Nearby drop / soul prompts (bounded scan)",get=function() return vv().Drops end,set=sv("Drops")})
    local _,o=U.card(page,"Labels","",{order=2})
    U.toggle(o,{label="Name",get=function() return vv().ShowName end,set=sv("ShowName")})
    U.toggle(o,{label="Distance",get=function() return vv().ShowDistance end,set=sv("ShowDistance")})
    U.toggle(o,{label="Health",get=function() return vv().ShowHealth end,set=sv("ShowHealth")})
    U.label(o,"Range",12,C.sub,U.F.semi)
    U.segment(o,{{"250",250},{"500",500},{"1000",1000},{"1500",1500}},function() return vv().MaxDistance end,setc("Visuals.MaxDistance"))
    stateRow(o,"Status",function() return (V and V.state) or "OFF",(V and V.count and V.count>0) and (V.count.." tracked") or "" end)
end
return true]==========]); if not ok then return end end
do local ok=runChunk("UI384_Mount.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local RAVYN=CTX["RAVYN"]
local U=CTX["UI384"]
local C=U.C
local UIS=game:GetService("UserInputService")
-- v3.9 simple sidebar; developer pages (dev=true) only appear in Developer Mode
local PAGES={
    {"Home","◆",{"home","start","go","status"},"buildHome"},
    {"Auto","◎",{"auto","play","mode","boss rotation"},"buildAutoPlay"},
    {"Combat","✦",{"combat","skill","speed","m1","ragdoll","stun","knockback"},"buildCombat"},
    {"Boss","◉",{"boss","farm","mob","target","npc","aura","rotation"},"buildBoss"},
    {"Quests","◇",{"quest","crow","muzan"},"buildQuests"},
    {"Loot","◈",{"loot","chest","drop"},"buildLoot"},
    {"Travel","➤",{"travel","hover","noclip","teleport","place","height"},"buildTravel"},
    {"Training","☯",{"training","breathing","trainer","station","mastery"},"buildTraining"},
    {"Dungeon","▣",{"dungeon","ouwigahara","card","floor"},"buildDungeon"},
    {"Visuals","◐",{"visuals","esp","highlight","chest","drop"},"buildVisuals"},
    {"Intelligence","✧",{"face","dodge","guard","threat","learn","loadout"},"buildIntelligence",true},
    {"Research","⌬",{"research","probe","learn","evidence","knowledge"},"buildResearch",true},
    {"Diagnostics","⌘",{"diag","log","feed","debug","error"},"buildDiagnostics",true},
    {"Settings","⚙",{"settings","esp","afk","save","motion","developer","advanced"},"buildSettings"},
}
local BADGES={
    Quests=function(S) local e=U.explain(S.quest.fail); if S.questEnabled and not S.autoplay then return C.orange end; return (e and e.color~=C.gold and e.color~=C.cyan) and e.color or nil end,
    Combat=function(S)
        local bs=U.busStatus and U.busStatus()
        if bs and bs.mode=="SILENT" and bs.physicalCombat>0 then return C.red end
        if bs and bs.mode=="SILENT" and bs.caps.ATTACK.status~="VERIFIED_SILENT" then return C.orange end
        if not RAVYN.Config.Combat.AutoAbilities then return nil end; local e=U.explain(S.skillFail); return (e and (e.color==C.red or e.color==C.orange)) and e.color or nil end,
    Loot=function(S) return S.loot.fail and C.orange or nil end,
    Diagnostics=function(S) return S.errorRecent and C.red or nil end,
}

local function mount()
    if not RAVYN.Config.UI.Enabled then return end
    local player=game:GetService("Players").LocalPlayer; local pg=player and player:FindFirstChildOfClass("PlayerGui"); if not pg then return end
    local old=pg:FindFirstChild("RAVYN_V384"); if old then old:Destroy() end
    local gui=U.n("ScreenGui",pg,{Name="RAVYN_V384",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=true,DisplayOrder=50})
    RAVYN._gui=gui; U.gui=gui
    local cam=workspace.CurrentCamera
    local function sizeFor() local v=(cam and cam.ViewportSize) or Vector2.new(1600,900); return math.floor(math.clamp(v.X*.68,860,1240)),math.floor(math.clamp(v.Y*.82,560,780)) end
    local W,H=sizeFor()
    local shadow=U.n("Frame",gui,{Name="Shadow",Size=UDim2.fromOffset(W+24,H+24),Position=UDim2.new(.5,-(W+24)/2,.5,-(H+24)/2+4),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.72,BorderSizePixel=0}); U.round(shadow,28)
    -- v3.8.4.3: plain Frame. A window-sized CanvasGroup re-renders its whole texture on every descendant change,
    -- which flickered under combat telemetry. Open/hide animate UIScale only.
    local win=U.n("Frame",gui,{Name="Window",Size=UDim2.fromOffset(W,H),Position=UDim2.new(.5,-W/2,.5,-H/2),BackgroundColor3=C.bg,BorderSizePixel=0,Active=true,ClipsDescendants=true})
    U.round(win,20); U.stroke(win,C.line,1,.15)
    U.n("UISizeConstraint",win,{MinSize=Vector2.new(720,480)})
    local scale=U.n("UIScale",win,{Scale=.96})
    U.anim(scale,.3,{Scale=1})
    -- header
    local top=U.n("Frame",win,{Size=UDim2.new(1,0,0,60),BackgroundColor3=C.panel,BorderSizePixel=0,Active=true})
    U.n("Frame",top,{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=C.line,BorderSizePixel=0})
    U.label(top,"RAVYN",20,C.text,U.F.bold,{Size=UDim2.fromOffset(90,60),Position=UDim2.fromOffset(20,0),TextWrapped=false})
    local gchip=U.n("Frame",top,{Size=UDim2.fromOffset(260,28),Position=UDim2.fromOffset(112,16),BackgroundColor3=C.raised,BorderSizePixel=0}); U.round(gchip,14)
    local halo=U.n("Frame",gchip,{Size=UDim2.fromOffset(8,8),Position=UDim2.new(0,16,.5,0),AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,BorderSizePixel=0}); U.round(halo,20)
    local haloStroke=U.stroke(halo,C.gray,1,.15)
    local gdot=U.n("Frame",gchip,{Size=UDim2.fromOffset(8,8),Position=UDim2.new(0,12,.5,-4),BackgroundColor3=C.gray,BorderSizePixel=0}); U.round(gdot,4)
    local gtext=U.label(gchip,"READY",11,C.text,U.F.bold,{Size=UDim2.new(1,-30,1,0),Position=UDim2.fromOffset(26,0),TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd})
    local ver=U.label(top,"",11,C.faint,U.F.body,{Size=UDim2.fromOffset(200,60),Position=UDim2.new(1,-300,0,0),TextXAlignment=Enum.TextXAlignment.Right,TextWrapped=false})
    local function topBtn(txt,x) local b=U.n("TextButton",top,{Size=UDim2.fromOffset(34,34),Position=UDim2.new(1,x,.5,-17),BackgroundColor3=C.card,Text=txt,TextColor3=C.text,TextSize=16,Font=U.F.bold,AutoButtonColor=false,BorderSizePixel=0}); U.round(b,10)
        table.insert(RAVYN._connections,b.MouseEnter:Connect(function() U.anim(b,.12,{BackgroundColor3=C.raised}) end)); table.insert(RAVYN._connections,b.MouseLeave:Connect(function() U.anim(b,.14,{BackgroundColor3=C.card}) end)); return b end
    local hideB=topBtn("—",-84); local closeB=topBtn("×",-44)
    local lastGlobal=nil
    U.addRefresh(function(S)
        U.setText(gtext,S.global); U.setColor(gtext,"TextColor3",S.globalColor); U.setColor(gdot,"BackgroundColor3",S.globalColor); U.setColor(gchip,"BackgroundColor3",U.dimOf(S.globalColor)); U.setText(ver,"v"..S.version)
        if lastGlobal~=S.global then
            lastGlobal=S.global; halo.Size=UDim2.fromOffset(8,8); haloStroke.Transparency=.1; haloStroke.Color=S.globalColor
            U.anim(halo,.48,{Size=UDim2.fromOffset(26,26)},Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
            U.anim(haloStroke,.5,{Transparency=1},Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
        end
    end)
    -- sidebar
    local side=U.n("Frame",win,{Size=UDim2.new(0,220,1,-60),Position=UDim2.fromOffset(0,60),BackgroundColor3=C.panel,BorderSizePixel=0})
    local search=U.n("TextBox",side,{Size=UDim2.new(1,-24,0,40),Position=UDim2.fromOffset(12,12),BackgroundColor3=C.card,Text="",PlaceholderText="Filter pages… (Ctrl+K)",PlaceholderColor3=C.faint,TextColor3=C.text,TextSize=12,Font=U.F.body,ClearTextOnFocus=false,BorderSizePixel=0,TextXAlignment=Enum.TextXAlignment.Left}); U.round(search,9); U.pad(search,10,10,0,0); U.stroke(search,C.line,1,.4)
    local nav=U.n("ScrollingFrame",side,{Size=UDim2.new(1,-16,1,-68),Position=UDim2.fromOffset(8,64),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()}); U.list(nav,3)
    local marker=U.n("Frame",side,{Size=UDim2.fromOffset(3,22),Position=UDim2.fromOffset(8,70),BackgroundColor3=C.gold,BorderSizePixel=0,ZIndex=3}); U.round(marker,2)
    -- content
    local content=U.n("Frame",win,{Size=UDim2.new(1,-220,1,-60),Position=UDim2.fromOffset(220,60),BackgroundTransparency=1})
    local heading=U.label(content,"Home",24,C.text,U.F.bold,{Size=UDim2.new(1,-48,0,32),Position=UDim2.fromOffset(24,14),TextWrapped=false})
    local host=U.n("Frame",content,{Size=UDim2.new(1,-40,1,-62),Position=UDim2.fromOffset(20,54),BackgroundTransparency=1,ClipsDescendants=true})
    -- toasts + tooltip
    U.toastHost=U.n("Frame",content,{Size=UDim2.fromOffset(320,0),AutomaticSize=Enum.AutomaticSize.Y,Position=UDim2.new(1,-340,1,-20),AnchorPoint=Vector2.new(0,1),BackgroundTransparency=1,ZIndex=30})
    U.list(U.toastHost,6).VerticalAlignment=Enum.VerticalAlignment.Bottom
    local tip=U.n("Frame",gui,{Size=UDim2.fromOffset(280,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C.raised,BorderSizePixel=0,Visible=false,ZIndex=100}); U.round(tip,8); U.stroke(tip,C.line,1,.2); U.pad(tip,10,10,8,8)
    local tipL=U.label(tip,"",11,C.text,U.F.body,{AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0),ZIndex=101})
    function U.showTip(text) if not text then tip.Visible=false; return end; tipL.Text=text; local m=UIS:GetMouseLocation(); tip.Position=UDim2.fromOffset(m.X+14,m.Y+10); tip.Visible=true end
    -- pages
    local groups={}; U.activePage="Home"
    local function show(name)
        if not groups[name] or (U.activePage==name and groups[name].Visible) then return end
        local prev=groups[U.activePage]; U.activePage=name; U.setText(heading,name)
        if prev and prev~=groups[name] then
            U.anim(prev,.13,{Position=UDim2.fromOffset(-12,0)},Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
            local old=prev; task.delay(.14,function() if U.activePage~=old.Name and old.Parent then old.Visible=false end end)
        end
        local g=groups[name]; g.Visible=true; U.reveal(g,18)
        U.runPage(name) -- bring the newly shown page up to date once
        for n2,b in pairs(U.navButtons) do U.setColor(b,"TextColor3",n2==name and C.text or C.sub,.14); U.setColor(b,"BackgroundTransparency",n2==name and 0 or 1,.14) end
        task.defer(function() local b=U.navButtons[name]; if b then U.anim(marker,.24,{Position=UDim2.fromOffset(8,b.AbsolutePosition.Y-side.AbsolutePosition.Y+7)}) end end)
    end
    U.show=show
    U.onDevModeChanged=function(on)
        for n2 in pairs(U.devNav or {}) do local b=U.navButtons[n2]; if b then b.Visible=on end end
        if not on and U.devNav and U.devNav[U.activePage] then show("Home") end
    end
    for i,def in ipairs(PAGES) do
        local name=def[1]
        local g=U.n("Frame",host,{Name=name,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false})
        U.n("UIScale",g,{Name="RAVYN_PageScale",Scale=1})
        local sc=U.n("ScrollingFrame",g,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.faint,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollingDirection=Enum.ScrollingDirection.Y})
        U.list(sc,12); U.pad(sc,2,8,2,24)
        groups[name]=g; U.pages[name]=sc
        local b=U.n("TextButton",nav,{Size=UDim2.new(1,0,0,46),BackgroundColor3=C.raised,BackgroundTransparency=1,Text="  "..def[2].."  "..name,TextColor3=C.sub,TextSize=14,Font=U.F.semi,TextXAlignment=Enum.TextXAlignment.Left,AutoButtonColor=false,BorderSizePixel=0,LayoutOrder=i}); U.round(b,11)
        U.pressable(b,{hoverScale=1.01,pressScale=.975})
        local badge=U.n("Frame",b,{Size=UDim2.fromOffset(8,8),Position=UDim2.new(1,-18,.5,-4),BackgroundColor3=C.orange,BorderSizePixel=0,Visible=false}); U.round(badge,4)
        U.navButtons[name]=b; U.badges[name]=badge
        if def[5] then b.Visible=RAVYN.Config.UI.DeveloperMode==true; U.devNav=U.devNav or {}; U.devNav[name]=true end
        table.insert(RAVYN._connections,b.Activated:Connect(function() show(name) end))
        U.buildingPage=name
        local ok,err=pcall(U[def[4]],sc)
        U.buildingPage=nil
        if not ok then U.label(sc,"Page failed to build: "..tostring(err),12,C.red,U.F.mono,{AutomaticSize=Enum.AutomaticSize.Y}); RAVYN.Logger:log("ERROR","UI_PAGE_BUILD "..name,{error=tostring(err)}) end
    end
    groups.Home.Visible=true; U.navButtons.Home.TextColor3=C.text; U.navButtons.Home.BackgroundTransparency=0
    task.defer(function() local b=U.navButtons.Home; marker.Position=UDim2.fromOffset(8,b.AbsolutePosition.Y-side.AbsolutePosition.Y+7) end)
    U.addRefresh(function(S) for name,fn in pairs(BADGES) do local c=fn(S); local bd=U.badges[name]; if bd then bd.Visible=c~=nil; if c then bd.BackgroundColor3=c end end end end)
    -- search / command palette
    local function matches(q)
        local out={}
        local dev=RAVYN.Config.UI.DeveloperMode==true
        for _,def in ipairs(PAGES) do if dev or not def[5] then
            local hit=string.find(string.lower(def[1]),q,1,true)~=nil
            if not hit then for _,k in ipairs(def[3]) do if string.find(k,q,1,true) then hit=true; break end end end
            if hit then table.insert(out,def[1]) end
        end end
        return out
    end
    table.insert(RAVYN._connections,search:GetPropertyChangedSignal("Text"):Connect(function()
        local q=string.lower(search.Text or ""); local set={}
        if q~="" then for _,n2 in ipairs(matches(q)) do set[n2]=true end end
        local dev=RAVYN.Config.UI.DeveloperMode==true
        for n2,b in pairs(U.navButtons) do b.Visible=((q=="") or set[n2]==true) and (dev or not (U.devNav and U.devNav[n2])) end
    end))
    table.insert(RAVYN._connections,search.FocusLost:Connect(function(enter)
        if not enter then return end
        local q=string.lower(search.Text or "")
        if q=="stop" or q=="stop everything" then pcall(function() RAVYN:SetAutoPlay(false); RAVYN:Stop() end); U.toast("Stopped","success")
        elseif q=="start" or q=="go" then local r=RAVYN:Go(RAVYN.Config.Go.Goal); U.report(r,"RAVYN started")
        elseif q=="pause" then local r=RAVYN:GoPause(); U.report(r,"Paused")
        elseif q=="home" then show("Home")
        else local m=matches(q); if m[1] then show(m[1]) end end
        search.Text=""
    end))
    -- ── PREMIUM COMMAND PALETTE (Ctrl+K / /) ─────────────────────────────────
    local PALETTE_CMDS={
        {label="Start RAVYN",        sub="Begin auto play",          fn=function() local r=RAVYN:Go(RAVYN.Config.Go.Goal); U.report(r,"RAVYN started") end},
        {label="Pause RAVYN",        sub="Pause current session",    fn=function() local r=RAVYN:GoPause(); U.report(r,"Paused") end},
        {label="Stop RAVYN",         sub="Stop everything",          fn=function() pcall(function() RAVYN:SetAutoPlay(false); RAVYN:Stop() end); U.toast("Stopped","success") end},
    }
    for _,def2 in ipairs(PAGES) do
        if not def2[5] then table.insert(PALETTE_CMDS,{label="Go to "..def2[1], sub="Navigate · "..table.concat(def2[3],", "), fn=function() show(def2[1]) end}) end
    end
    -- v1.0.1: generation counter lives beside pal/palOpen so both closePalette and openCommandPalette share it
    local pal=nil; local palOpen=false; local palGen=0
    -- v1.0.1: row-level connections stored separately so renderList can disconnect them without polluting RAVYN._connections
    local paletteRowConns={}
    local function clearPaletteRowConns()
        for _,c in ipairs(paletteRowConns) do pcall(function() c:Disconnect() end) end
        paletteRowConns={}
    end
    local function buildCommandPalette()
        if pal then return end
        local ov=U.n("Frame",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.52,ZIndex=200,Visible=false,Active=true})
        local card=U.n("Frame",ov,{Size=UDim2.fromOffset(500,0),AutomaticSize=Enum.AutomaticSize.Y,Position=UDim2.new(.5,-250,.22,0),BackgroundColor3=C.panel,BorderSizePixel=0,ZIndex=201}); U.round(card,16); U.stroke(card,C.line,1,.08)
        local csc=U.n("UIScale",card,{Scale=.94})
        local inp=U.n("TextBox",card,{Size=UDim2.new(1,-32,0,56),Position=UDim2.fromOffset(16,0),BackgroundTransparency=1,Text="",PlaceholderText="Search commands or pages…",PlaceholderColor3=C.faint,TextColor3=C.text,TextSize=17,Font=U.F.semi,ClearTextOnFocus=false,BorderSizePixel=0,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=202})
        -- v1.0.1: Ctrl+K badge (widened from 36 to 52 px to fit the label)
        local kbd=U.label(card,"Ctrl+K",11,C.faint,U.F.mono,{Size=UDim2.fromOffset(52,20),Position=UDim2.new(1,-68,0,18),ZIndex=202,TextXAlignment=Enum.TextXAlignment.Center})
        U.round(U.n("Frame",card,{Size=UDim2.fromOffset(52,20),Position=UDim2.new(1,-68,0,18),BackgroundColor3=C.card,BorderSizePixel=0,ZIndex=201}),6)
        U.n("Frame",card,{Size=UDim2.new(1,-32,0,1),Position=UDim2.fromOffset(16,58),BackgroundColor3=C.line,ZIndex=202})
        -- v1.0.1: list is fixed-height so the palette never overflows the viewport; UISizeConstraint caps at 356 px
        -- AutomaticCanvasSize keeps internal scrolling working for long result sets
        local list=U.n("ScrollingFrame",card,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,Position=UDim2.fromOffset(0,62),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.faint,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ZIndex=202}); U.list(list,2); U.pad(list,4,4,4,8)
        U.n("UISizeConstraint",list,{MaxSize=Vector2.new(math.huge,356)})
        local rowFns={}
        local selI=1
        local function closePalette()
            -- v1.0.1: capture generation before the delay; only hide if palette has not been reopened since
            palOpen=false; inp.Text=""; clearPaletteRowConns()
            local gen=palGen
            U.anim(csc,.12,{Scale=.94}); U.anim(ov,.13,{BackgroundTransparency=1})
            task.delay(.14,function() if not palOpen and palGen==gen and ov.Parent then ov.Visible=false end end)
        end
        local function runSel()
            local fn=rowFns[selI]; if not fn then return end
            closePalette(); task.defer(fn)
        end
        local function setSelRow(idx,rows)
            selI=math.clamp(idx,1,#rows)
            for ri,r in ipairs(rows) do
                local active=(ri==selI)
                U.anim(r,.08,{BackgroundTransparency=active and 0 or 1,BackgroundColor3=active and C.raised or C.card})
            end
        end
        local function renderList(q)
            -- v1.0.1: disconnect previous row connections before destroying their owners
            clearPaletteRowConns()
            for _,c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
            rowFns={}; local rows={}; selI=1
            local lq=string.lower(q or "")
            for _,cmd in ipairs(PALETTE_CMDS) do
                local hit=(lq=="" or string.find(string.lower(cmd.label),lq,1,true) or (cmd.sub and string.find(string.lower(cmd.sub),lq,1,true)))
                if hit then
                    local ri=#rowFns+1; table.insert(rowFns,cmd.fn)
                    local row=U.n("TextButton",list,{Size=UDim2.new(1,-8,0,46),BackgroundColor3=C.raised,BackgroundTransparency=1,Text="",AutoButtonColor=false,BorderSizePixel=0,ZIndex=203,LayoutOrder=ri}); U.round(row,10)
                    table.insert(rows,row)
                    U.label(row,cmd.label,14,C.text,U.F.semi,{Size=UDim2.new(1,-20,0,24),Position=UDim2.fromOffset(14,4),TextWrapped=false,ZIndex=204})
                    U.label(row,cmd.sub or "",11,C.sub,U.F.body,{Size=UDim2.new(1,-20,0,17),Position=UDim2.fromOffset(14,26),TextWrapped=false,ZIndex=204,TextTruncate=Enum.TextTruncate.AtEnd})
                    local ci=ri
                    -- v1.0.1: row connections go into paletteRowConns, not RAVYN._connections
                    table.insert(paletteRowConns,row.MouseEnter:Connect(function() setSelRow(ci,rows) end))
                    table.insert(paletteRowConns,row.Activated:Connect(function() selI=ci; runSel() end))
                end
            end
            if #rows>0 then setSelRow(1,rows) end
        end
        -- Permanent palette connections stay in RAVYN._connections (cleaned up on Destroy)
        table.insert(RAVYN._connections,inp:GetPropertyChangedSignal("Text"):Connect(function() renderList(inp.Text) end))
        table.insert(RAVYN._connections,UIS.InputBegan:Connect(function(i,gp)
            if not palOpen then return end
            if i.KeyCode==Enum.KeyCode.Escape then closePalette()
            elseif i.KeyCode==Enum.KeyCode.Return or i.KeyCode==Enum.KeyCode.KeypadEnter then runSel()
            elseif i.KeyCode==Enum.KeyCode.Up then
                local rows2={}; for _,c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then table.insert(rows2,c) end end
                setSelRow(selI-1,rows2)
            elseif i.KeyCode==Enum.KeyCode.Down then
                local rows2={}; for _,c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then table.insert(rows2,c) end end
                setSelRow(selI+1,rows2)
            end
        end))
        table.insert(RAVYN._connections,ov.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then
                local mx,my=i.Position.X,i.Position.Y; local cp=card.AbsolutePosition; local cs=card.AbsoluteSize
                if mx<cp.X or mx>cp.X+cs.X or my<cp.Y or my>cp.Y+cs.Y then closePalette() end
            end
        end))
        pal={ov=ov,inp=inp,csc=csc,renderList=renderList,closePalette=closePalette}
    end
    local function openCommandPalette()
        buildCommandPalette()
        if palOpen then pal.closePalette(); return end
        -- v1.0.1: increment generation so any in-flight delayed close from the previous session is invalidated
        palGen=palGen+1
        palOpen=true; pal.ov.BackgroundTransparency=1; pal.ov.Visible=true; pal.csc.Scale=.94
        pal.renderList("")
        U.anim(pal.ov,.18,{BackgroundTransparency=.52})
        U.anim(pal.csc,.24,{Scale=1},Enum.EasingStyle.Back,Enum.EasingDirection.Out)
        task.defer(function() if pal.inp and pal.inp.Parent then pal.inp:CaptureFocus() end end)
    end
    table.insert(RAVYN._connections,UIS.InputBegan:Connect(function(i,gp)
        if gp then return end
        local ctrl=UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)
        if ctrl and i.KeyCode==Enum.KeyCode.K then openCommandPalette()
        elseif i.KeyCode==Enum.KeyCode.Slash and not ctrl then
            local focused=UIS:GetFocusedTextBox()
            if not focused then openCommandPalette() end
        end
    end))
    -- hide / restore / close / drag
    -- ── PREMIUM MINI HUD ────────────────────────────────────────────────────
    local pill=U.n("Frame",gui,{Size=UDim2.fromOffset(192,62),Position=UDim2.new(0,20,.5,-31),BackgroundColor3=C.panel,Visible=false,BorderSizePixel=0,Active=true}); U.round(pill,18); U.stroke(pill,C.line,1,.15)
    local pillScale=U.n("UIScale",pill,{Scale=.92})
    local pdot=U.n("Frame",pill,{Size=UDim2.fromOffset(9,9),Position=UDim2.new(0,16,.5,-18),BackgroundColor3=C.gray,BorderSizePixel=0}); U.round(pdot,5)
    local ptopL=U.label(pill,"RAVYN",13,C.gold,U.F.bold,{Size=UDim2.new(1,-36,0,20),Position=UDim2.fromOffset(32,10),TextWrapped=false,TextXAlignment=Enum.TextXAlignment.Left})
    local pstatL=U.label(pill,"IDLE",11,C.gray,U.F.semi,{Size=UDim2.new(1,-68,0,16),Position=UDim2.fromOffset(32,28),TextWrapped=false,TextXAlignment=Enum.TextXAlignment.Left})
    local pactL=U.label(pill,"—",10,C.sub,U.F.body,{Size=UDim2.new(1,-32,0,14),Position=UDim2.fromOffset(16,44),TextWrapped=false,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
    local prestore=U.n("TextButton",pill,{Size=UDim2.fromOffset(22,22),Position=UDim2.new(1,-30,.5,-11),BackgroundColor3=C.card,Text="↗",TextColor3=C.sub,TextSize=11,Font=U.F.bold,AutoButtonColor=false,BorderSizePixel=0}); U.round(prestore,7); U.stroke(prestore,C.line,1,.3)
    U.pressable(prestore,{hoverScale=1.04,pressScale=.94})
    -- pill drag
    local pdrag,pdStart,ppStart=false,nil,nil
    table.insert(RAVYN._connections,pill.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then pdrag=true; pdStart=i.Position; ppStart=pill.Position end end))
    table.insert(RAVYN._connections,UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then pdrag=false end end))
    table.insert(RAVYN._connections,UIS.InputChanged:Connect(function(i)
        if pdrag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-pdStart; pill.Position=UDim2.new(ppStart.X.Scale,ppStart.X.Offset+d.X,ppStart.Y.Scale,ppStart.Y.Offset+d.Y)
        end
    end))
    local busy=false
    local function setHidden(v)
        if busy or U.hidden==v then return end; busy=true
        if v then
            U.anim(scale,.16,{Scale=.94})
            task.delay(.17,function() win.Visible=false; shadow.Visible=false; U.hidden=true; pill.Visible=true; pillScale.Scale=.88; U.anim(pillScale,.22,{Scale=1},Enum.EasingStyle.Back,Enum.EasingDirection.Out); busy=false end)
        else
            U.hidden=false; pill.Visible=false; win.Visible=true; shadow.Visible=true; scale.Scale=.94
            U.anim(scale,.24,{Scale=1},Enum.EasingStyle.Back,Enum.EasingDirection.Out); U.runPage(U.activePage); task.delay(.25,function() busy=false end)
        end
    end
    table.insert(RAVYN._connections,hideB.Activated:Connect(function() setHidden(true) end))
    table.insert(RAVYN._connections,prestore.Activated:Connect(function() setHidden(false) end))
    table.insert(RAVYN._connections,closeB.Activated:Connect(function() RAVYN:Destroy() end))
    table.insert(RAVYN._connections,UIS.InputBegan:Connect(function(i,gp) if not gp and i.KeyCode==Enum.KeyCode.RightControl then setHidden(not U.hidden) end end))
    local drag,dStart,wStart=false,nil,nil
    table.insert(RAVYN._connections,top.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true; dStart=i.Position; wStart=win.Position end end))
    table.insert(RAVYN._connections,UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end end))
    table.insert(RAVYN._connections,UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-dStart; win.Position=UDim2.new(wStart.X.Scale,wStart.X.Offset+d.X,wStart.Y.Scale,wStart.Y.Offset+d.Y)
            shadow.Position=UDim2.new(win.Position.X.Scale,win.Position.X.Offset-12,win.Position.Y.Scale,win.Position.Y.Offset-8)
        end
    end))
    if cam then table.insert(RAVYN._connections,cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        local w2,h2=sizeFor(); win.Size=UDim2.fromOffset(w2,h2); shadow.Size=UDim2.fromOffset(w2+24,h2+24)
    end)) end
    -- event → toast bridge (quest/loot events only, deduped in U.toast)
    local seenQ,seenL=0,0
    local function bridge()
        local QB=RAVYN.QuestBrain; local LC=RAVYN.LootController
        if QB and QB.events then for i=seenQ+1,#QB.events do local e=QB.events[i]; if e.kind~="info" or string.find(e.text,"Level",1,true) then U.toast(e.text,e.kind) end end; seenQ=#QB.events end
        if LC and LC.events then for i=seenL+1,#LC.events do local e=LC.events[i]; U.toast(e.text,e.kind) end; seenL=#LC.events end
    end
    -- refresh loop: ~4 Hz visible, ~1 Hz hidden (pill only)
    task.spawn(function()
        while not RAVYN._destroyed and RAVYN._gui==gui do
            local ok,S=pcall(U.buildState)
            if ok and S then
                U.S=S
                U.setColor(pdot,"BackgroundColor3",S.globalColor)
                U.setText(pstatL,S.global); U.setColor(pstatL,"TextColor3",S.globalColor)
                local Dx=RAVYN.Direct; local ob=Dx and Dx.objective
                local act=(ob and ob.name and (ob.name..(ob.progress and string.format(" · %d/%d",ob.progress,ob.required or 0) or ""))) or (S.quest and S.quest.target and S.quest.target~="" and S.quest.target) or S.plain or "—"
                U.setText(pactL,act)
                if not U.hidden then
                    U.runGlobal(S); U.runPage(U.activePage)
                end
                pcall(bridge)
            else RAVYN.Logger:log("WARN","UI_STATE_BUILD",{error=tostring(S)}) end
            task.wait(U.hidden and 1 or .25)
        end
    end)
    RAVYN.Logger:log("INFO","UI_V384_MOUNTED",{pages=#PAGES})
end
CTX["mountUI"]=function()
    local ok,err=pcall(mount)
    if not ok then RAVYN.Logger:log("WARN","UI mount failed",{error=tostring(err)}) end
end
return true]==========]); if not ok then return end end
do local ok,res=runChunk("Boot.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local Hooks=CTX.Hooks
local Logger=CTX["Logger"]
local RAVYN=CTX["RAVYN"]
local mountUI=CTX["mountUI"]
local log=CTX["log"]
local env=(getgenv and getgenv()) or _G
local previous=env.RAVYN
if previous and previous~=RAVYN and type(previous.Destroy)=="function" then
    local ok,err=pcall(function() previous:Destroy() end)
    if not ok then RAVYN.Logger:log("WARN","PREVIOUS_RUNTIME_CLEANUP_FAILED",{error=tostring(err)}) end
end
env.RAVYN=RAVYN
pcall(function() RAVYN:LoadSettings() end)
RAVYN.Registry:refresh()
print("RAVYN DIRECT v1.2.2 | SILENT COMBAT BUS | INSTAKILL HARDENING | DIRECT CROW | BOSS FARM | BOSS LOOT V2 | PREMIUM MOTION UI")
mountUI()
CTX["env"]=env
CTX["previous"]=previous
return RAVYN]==========]); if not ok then return end; if res then CTX.RAVYN=res end end
if not CTX.RAVYN then diag("RAVYN BOOT FAILED · RUNTIME MISSING",true); return end
if not CTX.RAVYN._gui then
    local detail="UI_NOT_MOUNTED"
    local entries=CTX.RAVYN.Logger and CTX.RAVYN.Logger.entries
    if entries and #entries>0 then detail=detail.." · "..tostring(entries[#entries].message or "") end
    diag("RAVYN DIRECT v1 BOOT PASS · "..detail,true)
    return CTX.RAVYN
end
diag("RAVYN DIRECT v1.2.2 READY · SILENT COMBAT · INSTAKILL HARDENING",false)
task.delay(5,function() if diagGui then pcall(function() diagGui:Destroy() end) end end)
return CTX.RAVYN
