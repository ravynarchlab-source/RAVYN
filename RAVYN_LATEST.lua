-- RAVYN v3.8.5 LOCAL MODULAR LOADER · GAME KNOWLEDGE + LEARN ACTION
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
Config.Default.Movement={SpeedEnabled=false,Speed=16,MinSpeed=8,MaxSpeed=32,TravelMode="Tween",TweenSpeed=150}
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

Hooks.pressMouse1=function()
    -- Cursor-dependent executor click input is intentionally avoided. v3.8.2 later replaces
    -- this dispatcher with a fixed-screen input path before Boot executes.
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

    if hp<=smart.CriticalHealthPercent then LiveAction.evading=true end
    if not LiveAction.evading and hp<=smart.LowHealthPercent then LiveAction.evading=true end
    if LiveAction.evading and hp>=smart.RecoveryPercent then LiveAction.evading=false end

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
    local now=os.clock()
    local dest,positionMode=Hooks.smartDestination(target,now)
    if not dest then return result(false,positionMode or "DESTINATION_UNAVAILABLE") end
    local targetPos=targetBasis(target)
    local dist=(root.Position-dest).Magnitude
    local profile=Hooks.activeProfile()

    local useTeleport=instant or RAVYN.Config.Movement.TravelMode=="Teleport"
    local cm2=RAVYN.Config and RAVYN.Config.CombatMobility
    if cm2 and cm2.Enabled and cm2.NoCombatTeleport and LiveAction.target then useTeleport=false
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
    local maxDistance=allowMove and math.min(cfg.MaxDistance,cfg.TargetRadius) or math.max(22,Hooks.activeProfile().attackDistance*1.75)

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
    local ok,source=Hooks.pressMouse1()
    LiveAction.lastInputSource=source
    self.Logger:log(ok and "INFO" or "WARN",ok and "M1_INPUT" or source,{source=source})
    return result(ok,ok and "ATTACK_INPUT_SENT" or source)
end

function RAVYN:ClientSkill()
    local keys=currentSkillKeys()
    if #keys==0 then return result(false,"NO_VISIBLE_SKILL_KEYS") end
    LiveAction.skillCursor=(LiveAction.skillCursor%#keys)+1
    local chosen=keys[LiveAction.skillCursor]
    local ok,src=pressKey(chosen.key)
    LiveAction.lastInputSource=src
    self.Logger:log(ok and "INFO" or "WARN",ok and ("SKILL_INPUT_"..chosen.key) or src,{source=src,index=chosen.index})
    return result(ok,ok and "SKILL_INPUT_SENT" or src,chosen)
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
local pressKey=CTX["pressKey"]
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
    local maxDistance=allowMove and math.min(cfg.MaxDistance or math.huge,cfg.TargetRadius or math.huge,smartSearchRadius()) or math.max(22,Hooks.activeProfile().attackDistance*1.75)
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
    local ok,src=pressKey(best.key); LiveAction.lastInputSource=src
    if ok then Brain.combo.lastSkillKey=best.key; Brain.combo.lastSkillAt[best.key]=now; Brain.combo.stage=(Brain.combo.stage%#keys)+1; Brain.combo.m1=0; Brain.combo.lastAction="SKILL "..best.key; self.Logger:log("INFO","SMART_SKILL_"..best.key,{target=target and target.name,index=best.index}); return result(true,"SMART_SKILL_SENT",best) end
    return result(false,src,best)
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
    local vu=liveService("VirtualUser"); if vu then pcall(function() vu:CaptureController(); vu:ClickButton2(Vector2.new(0,0)) end) end
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
local pressKey=CTX["pressKey"]
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
    local cam=workspace.CurrentCamera
    local vp=cam and cam.ViewportSize or Vector2.new(1280,720)
    local x,y=math.floor(vp.X*.5),math.floor(vp.Y*.5)
    local gui=RAVYN._gui; local guiWasEnabled=nil
    if gui then pcall(function() guiWasEnabled=gui.Enabled; gui.Enabled=false end) end
    local function restore() if gui and guiWasEnabled~=nil then pcall(function() gui.Enabled=guiWasEnabled end) end end
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
    if now-(Evolution.lastGuardResolve or 0)<2.0 then return Evolution.guardKey,Evolution.guardSource end
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

local function releaseGuard()
    if Evolution.guardDown and Evolution.guardKey then setKeyState(Evolution.guardKey,false) end
    Evolution.guardDown=false; Evolution.guardReleaseAt=0
end
local function holdGuard(now,duration)
    local cfg=evoCfg().Defense; if not cfg.ReactiveGuard then return false,"GUARD_DISABLED" end
    local key,source=resolveGuardKey(now); if not key then return false,source end
    if isSkillConflict(key) then return false,"GUARD_KEY_CONFLICT" end
    if not Evolution.guardDown then
        local ok,src=setKeyState(key,true); if not ok then return false,src end
        Evolution.guardDown=true; Evolution.guardKey=key; Evolution.guardSource=source.."/"..src
    end
    Evolution.guardReleaseAt=math.max(Evolution.guardReleaseAt or 0,now+(duration or cfg.GuardHold))
    Brain.combo.lastAction="GUARD "..key
    return true,Evolution.guardSource
end

local function directionalDodge(side)
    local cfg=evoCfg().Defense; local q=tostring(cfg.DodgeKey or "Q")
    if isSkillConflict(q) then return false,"DODGE_KEY_CONFLICT:"..q end
    local vim=liveService("VirtualInputManager")
    if not vim then return false,"DODGE_INPUT_UNAVAILABLE" end
    local sideKey=side<0 and Enum.KeyCode.A or Enum.KeyCode.D
    local dodge=keyCodeFromText(q); if not dodge then return false,"DODGE_KEY_UNMAPPED" end
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
    if target then faceCurrentTarget(target) end
    if cfg.Enabled and cfg.UseHeavyAttack and target and now-(Evolution.heavyLast or 0)>=cfg.HeavyCooldown and Brain.combo.m1>=math.max(2,math.floor(cfg.HeavyAfterM1 or 3)) then
        local pct=(target.health and target.maxHealth and target.maxHealth>0) and (target.health/target.maxHealth*100) or 100
        local afterSkill=string.find(tostring(Brain.combo.lastAction or ""),"SKILL",1,true)~=nil
        if pct<=38 or afterSkill then
            local ok,src=pressMouse2(); LiveAction.lastInputSource=src
            if ok then Evolution.heavyLast=now; Brain.combo.m1=0; Brain.combo.lastAction="M2 HEAVY"; self.Logger:log("INFO","COMBO_HEAVY",{target=target.name,hpPct=pct}); return result(true,"HEAVY_INPUT_SENT",{source=src}) end
        end
    end
    local ok,src=Hooks.pressMouse1(); LiveAction.lastInputSource=src
    self.Logger:log(ok and "INFO" or "WARN",ok and "M1_FIXED_INPUT" or src,{source=src,target=target and target.name})
    return result(ok,ok and "ATTACK_INPUT_SENT" or src)
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
    local ok,src=pressKey(best.key); LiveAction.lastInputSource=src
    if ok then
        Brain.combo.lastSkillKey=best.key; Brain.combo.lastSkillAt[best.key]=now; Brain.combo.stage=(Brain.combo.stage%#keys)+1; Brain.combo.m1=0; Brain.combo.lastAction="SKILL "..best.key
        Evolution.skillUseCount+=1; Evolution.skillLockUntil=now+(cfg.Learning.SkillLock or .42)
        Evolution.pendingSkill={key=best.key,targetId=target and target.id,hpBefore=target and target.health,maxHealth=target and target.maxHealth,at=now}
        self.Logger:log("INFO","ADAPTIVE_SKILL_"..best.key,{target=target and target.name,index=best.index,score=bestScore})
        return result(true,"ADAPTIVE_SKILL_SENT",best)
    end
    return result(false,src,best)
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
        if RAVYN.FSM.state=="RUNNING" and evoCfg().Enabled then
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
        local texts={}; local seen={}
        local p=game:GetService("Players").LocalPlayer; local pg=p and p:FindFirstChildOfClass("PlayerGui")
        if not pg then return texts end
        local desc=safe(function() return pg:GetDescendants() end,{})
        local n=0
        for _,g in ipairs(desc) do
            n=n+1; if n>2200 or #texts>=140 then break end
            if g:IsA("TextLabel") or g:IsA("TextButton") then
                local vis=safe(function() return g.Visible end,false)
                local txt=vis and clean(safe(function() return g.Text end,"")) or ""
                if txt~="" then
                    local chain=""; local cur=g
                    for _=1,5 do
                        if not cur then break end
                        chain=chain.."/"..low(safe(function() return cur.Name end,"")); cur=safe(function() return cur.Parent end,nil)
                    end
                    local l=low(txt)
                    local named=string.find(chain,"quest",1,true) or string.find(chain,"objective",1,true) or string.find(chain,"mission",1,true) or string.find(chain,"crow",1,true) or string.find(chain,"muzan",1,true)
                    local semantic=string.find(l,"kill",1,true) or string.find(l,"defeat",1,true) or string.find(l,"slay",1,true) or string.find(l,"eliminate",1,true) or string.find(l,"collect",1,true) or string.find(l,"gather",1,true) or string.find(l,"talk",1,true) or string.find(l,"speak",1,true) or string.find(l,"return",1,true) or string.find(l,"objective",1,true) or string.find(l,"mission",1,true) or string.find(l,"quest",1,true)
                    if (named or semantic) and not seen[txt] then seen[txt]=true; table.insert(texts,txt) end
                end
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
        local best,bestScore=nil,-math.huge; local list=safe(function() return workspace:GetDescendants() end,{})
        local cap=0
        for _,x in ipairs(list) do
            cap=cap+1; if cap>6500 then break end
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
    TweenMaxDist=70,        -- 0..70 tween
    FastTweenMaxDist=220,   -- 70..220 fast tween, >220 teleport once
    TweenSpeed=190,
    FastTweenSpeed=320,
    TeleportCooldown=4,
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
        for _,k in ipairs({"CombatRadius","CombatExitRadius","TweenMaxDist","FastTweenMaxDist","TweenSpeed","FastTweenSpeed","TeleportCooldown","RetweenDrift","StuckTimeout","ArriveHeight","NoclipReleaseGrace"}) do
            if type(t[k])~="number" or t[k]~=t[k] or t[k]<0 then table.insert(errors,"TravelController."..k) end
        end
        if type(t.TravelNoclip)~="boolean" or type(t.CombatNoclip)~="boolean" then table.insert(errors,"TravelController.Noclip") end
        if type(t.CombatExitRadius)=="number" and type(t.CombatRadius)=="number" and t.CombatExitRadius<t.CombatRadius then table.insert(errors,"TravelController.CombatExitRadius") end
    end
    return #errors==0,errors
end
local function tc() return RAVYN.Config.TravelController end

local MO={
    current="IDLE",previous="IDLE",since=os.clock(),reason="BOOT",transitions=0,history={},
    bypass=false,external=nil,
    travelTween=nil,travelDest=nil,travelKey=nil,travelMode="—",travelStartedAt=0,
    progressPos=nil,progressAt=0,lastTeleportAt=-math.huge,lastTeleportKey=nil,teleports=0,tweens=0,
    lastTargetSeenAt=0,liveDistance=nil,
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
        if not wantHover and d>c.FastTweenMaxDist and now-(MO.lockSince or now)<.35 then
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
        local conn=p.CharacterAdded:Connect(function()
            stopTravelTween(); noclipDisable("RESPAWN"); MO.lastTeleportKey=nil; setOwner("IDLE","RESPAWN")
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
    local radius=math.min(cfg.MaxDistance or math.huge,cfg.TargetRadius or math.huge,RADIUS_MAP[RAVYN.Config.Intelligence.SearchRadius] or 250)
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
    -- v3.8.4.1: Crow + Muzan are part of the one-switch Auto Play preset (they only ever run while
    -- Auto Play is ON). Each toggle can still be turned off individually. Generic givers stay opt-in.
    AutoQuest=false, AutoCrow=true, AutoMuzan=true, PresetVersion=1,
    -- v3.8.5: an unresolved quest target is investigated through evidence (quest markers), not random farming.
    -- Learning by killing nearby mobs is opt-in.
    LearnByNearbyKills=false,
    RepeatCrow=true, RepeatMuzan=true, AutoTurnIn=true,
    SourceScanInterval=3, InteractTimeout=8, SourceBackoff=30, StallSeconds=90,
    KnownSources={}, TargetMemory={},
}
Config.Default.QuestBrain=Util.deepCopy(defaults)
do
    local saved=RAVYN.Config.QuestBrain
    -- one-time preset migration: settings saved before the preset existed get Crow/Muzan enabled once;
    -- after that, the user's own toggles are respected.
    if type(saved)=="table" and (tonumber(saved.PresetVersion) or 0)<1 then saved.AutoCrow=true; saved.AutoMuzan=true; saved.PresetVersion=1 end
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
local function wantedType(t)
    local c=qc()
    if t=="CROW" then return c.AutoCrow end
    if t=="MUZAN" then return c.AutoMuzan end
    return c.AutoQuest
end
local function enabled()
    local c=qc()
    return RAVYN.Config.Intelligence and RAVYN.Config.Intelligence.AutoPlay and (c.AutoQuest or c.AutoCrow or c.AutoMuzan)
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

local function tick()
    local now=os.clock()
    if not enabled() or not (RAVYN.FSM and RAVYN.FSM.state=="RUNNING") then
        QB.navigating=false; QB.learnedOverride=nil; QB.phase="IDLE"
        if QB.state~="IDLE" then setState("IDLE",nil) end
        return
    end
    local A=RAVYN.AdaptiveIntel
    if not A then setState("ADAPTIVE INTEL MISSING","ADAPTIVE_INTEL_UNAVAILABLE"); QB.navigating=false; return end
    local q=A.quest or {state="NONE"}
    levelCheck(); scanSources(now); learn(q,now)
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
    KillLootRadius=26, ChestSearchRadius=80, ImmediateChestRadius=40, ChestScanInterval=1.5,
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
    local keep={"QUEST · ","LOOT · ","MOVE_OWNER","TRAVEL_TELEPORT","TRAVEL_STUCK","NOCLIP_RESTORED","ADAPTIVE_LOADOUT_CHANGED","ADAPTIVE_QUEST_CHANGED","AUTOPLAY_BOSS_DOWN","SMART_SKILL_"}
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
RAVYN.Version="3.8.5-game-knowledge"
RAVYN.Build="2026-09-27-v3.8.5-game-knowledge"
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
    HoverMode="ABOVE_BEHIND", FlyHeight=5.5, FlyBehindOffset=2.5, OrbitRadius=4.5, OrbitSpeed=1.6,
    FlySpeed=110, VerticalSpeed=70, PositionGain=9,
    TurboM1=true, M1Interval=.09, HoldCombo=true, ComboLength=3,
    AggressiveSkills=true, SkillInterval=.48, SkillCastLock=.45, SkillBackoff=8, ConservativeRetry=3,
    RecoveryDistance=40, RecoveryHeight=22, RecoveryStrafeSpeed=.35,
    KeepComboUnderHit=true,
    NoRagdoll=true, NoStun=false, NoKnockback=false, NoAttackSlowdown=false,
    AntiRagdoll=true, AntiStun=false, -- legacy keys kept for saved settings compatibility
}
Config.Default.CombatMobility=Util.deepCopy(defaults)
local saved=RAVYN.Config.CombatMobility or {}
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
        return tp+Vector3.new(math.cos(M.orbitAngle)*c.OrbitRadius,h,math.sin(M.orbitAngle)*c.OrbitRadius),tp
    end
    return tp-flatLook*c.FlyBehindOffset+Vector3.new(0,h,0),tp
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
local pressKey=CTX["pressKey"]
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
local function sendSkill(k,target,dist,now)
    local s=stat(k.key); s.attempts=s.attempts+1; M.skillAttempts=M.skillAttempts+1
    pcall(function() if faceCurrentTarget then faceCurrentTarget(target) end end)
    local sigBefore=slotSignature(k.index); local tracksBefore=animSet()
    local ok,src=pressKey(k.key); LiveAction.lastInputSource=src
    if not ok then s.lastFail=tostring(src); M.skillFailReason="INPUT_UNAVAILABLE"; return false end
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
    local atDecision=(not c.HoldCombo) or M.comboStage>=math.max(1,c.ComboLength) or not RAVYN.Config.Combat.AutoAttack
    local nextSkill=nil
    if RAVYN.Config.Combat.AutoAbilities then
        local keys=refreshKeys(now)
        if #keys==0 then
            M.nextAction="M1"
            if now-M.lastNoKeyAt>=1.5 then
                M.lastNoKeyAt=now; M.skillAttempts=M.skillAttempts+1
                M.skillFailReason=M.everHadKeys and "SKILL_HOTBAR_NOT_READY" or "HOTBAR_KEYS_UNRESOLVED"
            end
        elseif not M.pending and now-(LiveAction.lastSkill or 0)>=math.max(.25,c.SkillInterval) then
            local k,why=pickSkill(target,dist,now); nextSkill=k
            if k and atDecision and dist<=math.max(skillRange,(stat(k.key).maxRange or 0)+2) then
                if sendSkill(k,target,dist,now) then M.combatState=(pct<=25) and "FINISHER" or "SKILL_CAST"; M.nextAction="VERIFY "..k.key; return end
            elseif not k then M.skillFailReason=why end
        end
    end
    M.nextAction=(nextSkill and atDecision) and ("SKILL "..nextSkill.key) or "M1"
    -- M1 (blocked while a skill cast lock is active)
    if c.TurboM1 and RAVYN.Config.Combat.AutoAttack and dist<=m1Range and now>=M.inputLockUntil and now-(LiveAction.lastAttack or 0)>=math.max(.05,c.M1Interval) then
        M.m1Attempts=M.m1Attempts+1
        local ok,r=pcall(function() return RAVYN:ClientAttack() end)
        if ok and r and r.ok then
            LiveAction.lastAttack=now; Brain.combo.m1=(Brain.combo.m1 or 0)+1; Brain.combo.lastAction="M1"
            M.m1Sent=M.m1Sent+1; M.m1Count=M.m1Sent; M.comboStage=M.comboStage+1
            M.lastAction=string.format("M1 ×%d",M.comboStage); M.combatState=(pct<=25) and "FINISHER" or "M1_CHAIN"
            if M.comboStage>math.max(1,c.ComboLength)*3 then M.comboStage=math.max(1,c.ComboLength) end
        end
    elseif dist>m1Range then M.combatState="HOVER_LOCK" end
end

local baseProfile=Hooks.activeProfile
Hooks.activeProfile=function()
    local p=baseProfile(); local c=cfg()
    if c.Enabled and c.TurboM1 then p.attackCooldown=math.min(p.attackCooldown or .4,math.max(.05,tonumber(c.M1Interval) or .09)) end
    if c.Enabled and c.AggressiveSkills then p.skillDelay=math.min(p.skillDelay or 1,math.max(.25,tonumber(c.SkillInterval) or .48)) end
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
    if bp then for _,t in ipairs(bp:GetChildren()) do table.insert(out.tools,t.Name) end end
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
PR.guiSnapshot=guiSnapshot; PR.worldSnapshot=worldSnapshot; PR.playerSnapshot=playerSnapshot

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
        local own=RAVYN._gui; local n=0
        for _,d in ipairs(pg:GetDescendants()) do
            if n>=700 then break end
            if d:IsA("GuiButton") and not (own and d:IsDescendantOf(own)) then
                n=n+1
                table.insert(rec.conns,d.Activated:Connect(function()
                    rec.buttons=rec.buttons or {}
                    local txt=d:IsA("TextButton") and d.Text or ""
                    local lbl=d:FindFirstChildWhichIsA("TextLabel",true)
                    table.insert(rec.buttons,{path=d:GetFullName(),text=short(txt~="" and txt or (lbl and lbl.Text) or "",60)})
                    ev("BUTTON "..d:GetFullName().." '"..short(txt~="" and txt or (lbl and lbl.Text) or "",40).."'")
                end))
            end
        end
    end
end
function RAVYN:LearnActionBegin(label,system)
    if PR.recording then return result(false,"ALREADY_RECORDING") end
    local g,gn=guiSnapshot()
    PR.recording={label=tostring(label or "Custom action"),system=system or "OTHER",at=os.clock(),clock=os.date("%H:%M:%S"),
        gui=g,guiCount=gn,world=worldSnapshot(80),player=playerSnapshot(),conns={}}
    startHooks(PR.recording)
    RAVYN.Logger:log("INFO","LEARN_ACTION_BEGIN",{label=PR.recording.label})
    return result(true,"RECORDING",{label=PR.recording.label,guiNodes=gn})
end
function RAVYN:LearnActionEnd()
    local rec=PR.recording; if not rec then return result(false,"NOT_RECORDING") end
    PR.recording=nil; stopHooks(rec)
    local g2=guiSnapshot(); local w2=worldSnapshot(80); local p2=playerSnapshot()
    local lines={string.format("LEARN ACTION · %s · system %s · %s → %s · %.1fs",rec.label,rec.system,rec.clock,os.date("%H:%M:%S"),os.clock()-rec.at),
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
    local evidence={actionName=rec.label,system=rec.system,at=os.clock(),clock=rec.clock,interactionCandidate=cand,confidence=conf,
        guiChanges=#ga+#gr+#gc,worldChanges=#wa+#wr,valueChanges=#va+#vr+#vc,text=text}
    table.insert(PR.records,evidence); while #PR.records>12 do table.remove(PR.records,1) end
    PR.lastReport=text; PR.captures=PR.captures+1
    local GK=RAVYN.GameKnowledge; if GK and GK.recordEvidence then pcall(GK.recordEvidence,evidence) end
    local wf,mf,isf=exec("writefile"),exec("makefolder"),exec("isfolder")
    if wf then pcall(function()
        if mf and isf and not isf("RAVYN") then mf("RAVYN") end
        if mf and isf and not isf("RAVYN/Probes") then mf("RAVYN/Probes") end
        local safe=string.gsub(rec.label,"[^%w]+","_")
        wf("RAVYN/Probes/"..os.date("%Y%m%d_%H%M%S").."_"..safe..".txt",text)
        evidence.file=true
    end) end
    RAVYN.Logger:log("INFO","LEARN_ACTION_END",{label=rec.label,candidate=cand,confidence=conf})
    return result(true,"ACTION_EVIDENCE",evidence)
end
function RAVYN:CancelLearnAction() local rec=PR.recording; if rec then stopHooks(rec); PR.recording=nil end; return result(true,"CANCELLED") end
function RAVYN:CopyLearnActionReport()
    local f=exec("setclipboard"); if not PR.lastReport then return result(false,"NO_ACTION_EVIDENCE") end
    if not f then return result(false,"SETCLIPBOARD_UNAVAILABLE") end
    pcall(f,PR.lastReport); return result(true,"ACTION_EVIDENCE_COPIED")
end
-- a recording is user-driven and intentionally survives Stop; Destroy ends it
local baseDestroy=RAVYN.Destroy
function RAVYN:Destroy() if PR.recording then stopHooks(PR.recording); PR.recording=nil end; return baseDestroy(self) end
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
    if not force and now-GK.markersAt<3 then return GK.markers end
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
do local ok=runChunk("UI384_Core.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local RAVYN=CTX["RAVYN"]
local LiveAction=CTX["LiveAction"]
local Brain=CTX["Brain"]
local result=CTX["result"]
-- RAVYN UI v3.8.4 · state-aware premium console.
-- Presentation only: reads a normalized UIState snapshot, calls public RAVYN:* setters. Never drives automation.
if type(RAVYN.Config.UI.ReducedMotion)~="boolean" then RAVYN.Config.UI.ReducedMotion=false end
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
function U.n(class,parent,props) local x=Instance.new(class); for k,v in pairs(props or {}) do x[k]=v end; x.Parent=parent; return x end
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
    QUEST_TARGET_UNRESOLVED={"Quest target unknown","RAVYN is observing nearby kills to learn the objective target.","gold"},
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
    local t=U.n("CanvasGroup",U.toastHost,{Size=UDim2.new(1,0,0,38),BackgroundColor3=C.raised,GroupTransparency=1,BorderSizePixel=0,LayoutOrder=math.floor(now*100)})
    U.round(t,12); U.stroke(t,color,1,.55)
    U.n("Frame",t,{Size=UDim2.new(0,3,1,-14),Position=UDim2.fromOffset(8,7),BackgroundColor3=color,BorderSizePixel=0})
    U.label(t,text,12,C.text,U.F.semi,{Size=UDim2.new(1,-28,1,0),Position=UDim2.fromOffset(20,0),TextTruncate=Enum.TextTruncate.AtEnd,TextWrapped=false})
    U.anim(t,.2,{GroupTransparency=0})
    task.delay(long and 5 or 2.6,function() if t.Parent then U.anim(t,.25,{GroupTransparency=1}); task.delay(.26,function() if t.Parent then t:Destroy() end end) end end)
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
    local b=U.n("TextButton",parent,{Size=UDim2.new(1,0,0,36),BackgroundColor3=col,Text=text,TextColor3=tc,TextSize=13,Font=U.F.semi,AutoButtonColor=false,BorderSizePixel=0}); U.round(b,10)
    local hover=(style=="accent" and Color3.fromRGB(84,70,32)) or (style=="danger" and Color3.fromRGB(84,26,28)) or C.raised
    table.insert(RAVYN._connections,b.MouseEnter:Connect(function() U.anim(b,.12,{BackgroundColor3=hover}) end))
    table.insert(RAVYN._connections,b.MouseLeave:Connect(function() U.anim(b,.16,{BackgroundColor3=col}) end))
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
        if e then U.setText(t,e.title); U.setColor(t,"TextColor3",e.color); U.setText(d,e.detail); U.setText(c,e.code) end
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

-- ================= HOME =================
function U.buildHome(page)
    -- hero
    local hero=U.n("Frame",page,{Size=UDim2.new(1,-4,0,86),BackgroundColor3=C.panel,BorderSizePixel=0,LayoutOrder=1}); U.round(hero,16); U.stroke(hero,C.line,1,.3)
    local accent=U.n("Frame",hero,{Size=UDim2.new(0,4,1,-28),Position=UDim2.fromOffset(14,14),BackgroundColor3=C.gray,BorderSizePixel=0}); U.round(accent,2)
    local state=U.label(hero,"READY",22,C.text,U.F.bold,{Size=UDim2.new(1,-220,0,30),Position=UDim2.fromOffset(30,14),TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd})
    local sub=U.label(hero,"",12,C.sub,U.F.body,{Size=UDim2.new(1,-220,0,18),Position=UDim2.fromOffset(30,48),TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd})
    local master=U.n("TextButton",hero,{Size=UDim2.fromOffset(168,44),Position=UDim2.new(1,-184,.5,-22),BackgroundColor3=C.raised,Text="",AutoButtonColor=false,BorderSizePixel=0}); U.round(master,22)
    local mStroke=U.stroke(master,C.gold,1,.6)
    local mDot=U.n("Frame",master,{Size=UDim2.fromOffset(10,10),Position=UDim2.new(0,18,.5,-5),BackgroundColor3=C.gray,BorderSizePixel=0}); U.round(mDot,5)
    local mText=U.label(master,"AUTO PLAY",13,C.text,U.F.bold,{Size=UDim2.new(1,-40,1,0),Position=UDim2.fromOffset(36,0),TextWrapped=false})
    local pending=false
    table.insert(RAVYN._connections,master.Activated:Connect(function()
        if pending then return end; pending=true
        local want=not (cfg().Intelligence.AutoPlay==true)
        U.setText(mText,want and "ACTIVATING…" or "STOPPING…")
        local ok,r=pcall(function() return RAVYN:SetAutoPlay(want) end)
        if not ok then U.toast(tostring(r),"error") else U.report(r,want and "Auto Play active" or "Auto Play off") end
        task.delay(.3,function() pending=false end)
    end))
    U.addRefresh(function(S)
        U.setText(state,S.global); U.setColor(state,"TextColor3",S.globalColor); U.setColor(accent,"BackgroundColor3",S.globalColor)
        U.setText(sub,"RAVYN "..S.version.."  ·  runtime "..S.fsm.."  ·  job "..S.job..(S.overlay and ("  ·  "..S.overlay) or ""))
        if not pending then U.setText(mText,S.autoplay and "AUTO PLAY ON" or "AUTO PLAY OFF") end
        U.setColor(mDot,"BackgroundColor3",S.autoplay and C.green or C.gray); U.setColor(master,"BackgroundColor3",S.autoplay and C.greenDim or C.raised)
        U.setColor(mStroke,"Color",S.autoplay and C.green or C.gold)
    end)
    -- pipeline
    local pipe=U.n("Frame",page,{Size=UDim2.new(1,-4,0,40),BackgroundTransparency=1,LayoutOrder=2}); U.list(pipe,6,Enum.FillDirection.Horizontal).VerticalAlignment=Enum.VerticalAlignment.Center
    local slots={}
    for i=1,5 do
        local chip=U.n("Frame",pipe,{Size=UDim2.new(.2,-8,0,32),BackgroundColor3=C.card,BorderSizePixel=0,LayoutOrder=i}); U.round(chip,10)
        local st=U.stroke(chip,C.gold,1,1)
        local l=U.label(chip,"",11,C.faint,U.F.bold,{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextWrapped=false})
        slots[i]={chip=chip,l=l,st=st}
    end
    local lastStage=nil
    U.addRefresh(function(S)
        local cur=0; for i,name in ipairs(S.stages) do if name==S.stage then cur=i end end
        for i,s in ipairs(slots) do
            local name=S.stages[i]; s.chip.Visible=name~=nil
            if name then
                s.chip.Size=UDim2.new(1/#S.stages,-8,0,32)
                U.setText(s.l,(i<cur and "✓ " or "")..name)
                local col=(i==cur and C.gold) or (i<cur and C.green) or C.faint
                U.setColor(s.l,"TextColor3",col); U.setColor(s.chip,"BackgroundColor3",i==cur and C.goldDim or C.card)
                U.setColor(s.st,"Transparency",i==cur and .55 or 1,.25) -- cached: tweens only when the stage changes
            end
        end
        lastStage=S.stage
    end)
    -- telemetry tiles
    local grid=U.n("Frame",page,{Size=UDim2.new(1,-4,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=3})
    U.n("UIGridLayout",grid,{CellSize=UDim2.new(.5,-5,0,72),CellPadding=UDim2.fromOffset(10,10),SortOrder=Enum.SortOrder.LayoutOrder})
    local function tile(order,key,fn)
        local t=U.n("Frame",grid,{BackgroundColor3=C.panel,BorderSizePixel=0,LayoutOrder=order}); U.round(t,14); U.stroke(t,C.line,1,.35)
        local bar=U.n("Frame",t,{Size=UDim2.new(0,3,1,-24),Position=UDim2.fromOffset(12,12),BackgroundColor3=C.gray,BorderSizePixel=0}); U.round(bar,2)
        U.label(t,key,11,C.sub,U.F.semi,{Size=UDim2.new(1,-34,0,16),Position=UDim2.fromOffset(24,10),TextWrapped=false})
        local v=U.label(t,"—",15,C.text,U.F.bold,{Size=UDim2.new(1,-34,0,20),Position=UDim2.fromOffset(24,27),TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd})
        local d=U.label(t,"",11,C.sub,U.F.body,{Size=UDim2.new(1,-34,0,16),Position=UDim2.fromOffset(24,48),TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd})
        U.addRefresh(function(S)
            -- metrics (counts, HP, distance) are plain text updates; only the semantic colour may tween (cached)
            local value,detail,color=fn(S); color=color or C.gray
            U.setText(v,value); U.setText(d,detail or ""); U.setColor(bar,"BackgroundColor3",color); U.setColor(v,"TextColor3",color==C.gray and C.text or color)
        end)
    end
    tile(1,"Activity",function(S) return S.activity,S.jobLabel~="" and S.jobLabel or ("job "..S.job),S.globalColor end)
    tile(2,"Target",function(S)
        if not S.target then return "No target",S.eligibleBosses>0 and (S.eligibleBosses.." eligible boss(es)") or "scanning",C.gray end
        local hp=S.target.hpPct and string.format("%d%% HP",math.floor(S.target.hpPct+.5)) or "HP ?"
        return (S.target.boss and "◆ " or "")..S.target.name,hp.."  ·  "..U.fmtDist(S.target.dist),S.target.boss and C.gold or C.green end)
    tile(3,"Quest",function(S)
        if not S.questEnabled then return "Off","enable in Quests",C.gray end
        local q=S.quest; local prog=q.progress and string.format("%d / %d",q.progress,q.required or 0) or ""
        return q.state,q.source.."  ·  "..(q.target or (q.objective=="KILL" and "learning target…" or q.objective)).."  "..prog,(q.fail and q.fail~="QUEST_TARGET_UNRESOLVED") and C.orange or C.purple end)
    tile(4,"Movement",function(S)
        local label=(S.owner=="COMBAT_HOVER" and "Combat Hover") or (S.owner=="TRAVEL" and "Travel") or (S.owner=="DEFENSE" and "Defense") or (S.owner=="RECOVERY" and "Recovery") or "Idle"
        local det=(S.owner=="TRAVEL" and S.travelMode) or (S.owner=="COMBAT_HOVER" and S.hover) or S.moveReason
        return label,det..(S.noclip and "  ·  noclip" or ""),U.ownerColor(S.owner) end)
    tile(5,"Combat",function(S)
        local e=U.explain(S.skillFail)
        local combo=S.combo>0 and ("M1 ×"..S.combo) or "—"
        if S.lastSkill and S.now-S.lastSkillAt<1.2 then combo=combo.." → Skill "..tostring(S.lastSkill) end
        return combo,string.format("%s · skills %d sent / %d verified",S.combatState,S.skills,S.verified),(S.combatState=="RECOVERY" and C.red) or (S.defense~="READY" and C.gold) or (S.target and C.green) or C.gray end)
    tile(6,"Health · Risk",function(S)
        if S.dead then return "DEAD","waiting for respawn",C.red end
        local hp=S.hpPct and string.format("%d%%",math.floor(S.hpPct+.5)) or "—"
        local risk=S.risk>=70 and "HIGH" or (S.risk>=40 and "ELEVATED" or "SAFE")
        return hp.."  ·  "..risk,string.format("risk %.0f  ·  %.0f dmg/s",S.risk,S.dps),(S.emergency and C.red) or U.hpColor(S.hpPct) end)
    -- stop everything with verified cleanup
    local stop=U.n("TextButton",page,{Size=UDim2.new(1,-4,0,44),BackgroundColor3=C.redDim,Text="Stop everything",TextColor3=C.red,TextSize=14,Font=U.F.bold,AutoButtonColor=false,BorderSizePixel=0,LayoutOrder=4}); U.round(stop,14); U.stroke(stop,C.red,1,.6)
    local busy=false
    table.insert(RAVYN._connections,stop.MouseEnter:Connect(function() U.anim(stop,.12,{BackgroundColor3=Color3.fromRGB(84,26,28)}) end))
    table.insert(RAVYN._connections,stop.MouseLeave:Connect(function() U.anim(stop,.16,{BackgroundColor3=C.redDim}) end))
    table.insert(RAVYN._connections,stop.Activated:Connect(function()
        if busy then return end; busy=true; stop.Text="Stopping…"; U.setColor(stop,"TextColor3",C.orange)
        pcall(function()
            RAVYN:SetAutoPlay(false)
            for _,f in ipairs({"NORMAL_MOB","BOSS","ATTACK","ABILITIES"}) do RAVYN:SetFeature(f,false) end
            RAVYN:SetKillAura(false)
            RAVYN:Stop()
        end)
        task.delay(.35,function()
            local MO=RAVYN.MoveOwner or {}; local NC=RAVYN.NoclipController or {}; local CM=RAVYN.CombatMobility or {}
            local problems={}
            if MO.current~="IDLE" then table.insert(problems,"movement "..tostring(MO.current)) end
            if NC.active then table.insert(problems,"noclip") end
            if CM.bodyVelocity or CM.bodyGyro then table.insert(problems,"movers") end
            if RAVYN.FSM.state~="STOPPED" then table.insert(problems,"runtime "..RAVYN.FSM.state) end
            if #problems==0 then
                stop.Text="Stopped · collision restored · movers removed · inputs released"; U.setColor(stop,"TextColor3",C.green)
                U.toast("Stopped · character restored","success")
            else
                stop.Text="Stop incomplete: "..table.concat(problems,", "); U.setColor(stop,"TextColor3",C.red); U.toast("Stop incomplete · see Diagnostics","error",true)
            end
            task.delay(3,function() busy=false; stop.Text="Stop everything"; U.setColor(stop,"TextColor3",C.red) end)
        end)
    end))
    -- profile + feed
    local _,prof=U.card(page,"Combat profile","One preset controls distances and tempo.",{order=5})
    U.segment(prof,{"Safe","Balanced","Aggressive"},function() return cfg().SmartCombat.Profile end,function(v) return RAVYN:SetSmartProfile(v) end)
    local _,feed=U.card(page,"Live activity","Most recent automation events.",{order=6,collapsible=true})
    local lines={}
    for i=1,6 do lines[i]=U.label(feed,"",11,C.sub,U.F.mono,{Size=UDim2.new(1,0,0,16),TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd}) end
    U.addRefresh(function()
        local f=(RAVYN.AutoPlay384 and RAVYN.AutoPlay384.feed) or {}
        for i=1,6 do
            local e=f[#f-i+1]
            if e then U.setText(lines[i],e.clock.."  "..e.text); U.setColor(lines[i],"TextColor3",(e.kind=="success" and C.green) or (e.kind=="warn" and C.orange) or (e.kind=="error" and C.red) or C.sub)
            else U.setText(lines[i],i==1 and "No events yet" or "") end
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
    local _,s=U.card(page,"Scheduler","Priority owner right now.",{order=2})
    U.kv(s,"Job",function(S) return S.job.."  ·  P"..S.priority,S.globalColor end)
    U.kv(s,"Interrupt",function(S) return S.overlay or "none",S.overlay and C.gold or C.gray end)
    U.kv(s,"Movement owner",function(S) return S.owner,U.ownerColor(S.owner) end)
    U.kv(s,"Eligible bosses",function(S) return tostring(S.eligibleBosses),S.eligibleBosses>0 and C.gold or C.gray end)
    local _,cap=U.card(page,"Capabilities","What Auto Play can actually execute today.",{order=3,collapsible=true})
    local rows={
        {"Travel · Hover · Combat","LIVE",C.green},{"Dynamic skills","LIVE",C.green},{"Threat learning / dodge","LIVE · evidence-gated",C.green},
        {"Quest accept / turn-in","PARTIAL · prompt + text verified",C.orange},{"Non-kill objectives","UNRESOLVED",C.gray},
        {"Chest / drop loot","PARTIAL · prompt verified",C.orange},{"Perfect parry","EVIDENCE REQUIRED",C.gray},{"Weapon equip","UNRESOLVED",C.gray},{"InstaKill","UNRESOLVED · not pursued",C.gray},
    }
    for _,r in ipairs(rows) do U.kv(cap,r[1],function() return r[2],r[3] end) end
end

-- ================= QUESTS =================
function U.buildQuests(page)
    local _,c=U.card(page,"Quest sources","Crow, Muzan and other quest givers share one quest brain. Sources are found at any streamed distance and approached automatically. Runs while Auto Play is on.",{order=1,
        warn=function(S) return (S.questEnabled and not S.autoplay) and C.orange or nil end})
    local qc=function() return cfg().QuestBrain end
    local qs=function(k) return function(v) return RAVYN:SetQuestOption(k,v) end end
    U.toggle(c,{label="Auto Crow quests",desc="Find Crow → accept → objective → turn in",get=function() return qc().AutoCrow end,set=qs("AutoCrow"),
        status=function(S,on) if not on then return "OFF",C.gray end; return (S.quest.source=="CROW" and S.quest.state) or "READY",S.autoplay and C.purple or C.orange end})
    U.toggle(c,{label="Repeat Crow",get=function() return qc().RepeatCrow end,set=qs("RepeatCrow"),dep=function() return qc().AutoCrow end,depText="Enable Auto Crow first"})
    U.toggle(c,{label="Auto Muzan quests",desc="Same lifecycle, Muzan as source",get=function() return qc().AutoMuzan end,set=qs("AutoMuzan"),
        status=function(S,on) if not on then return "OFF",C.gray end; return (S.quest.source=="MUZAN" and S.quest.state) or "READY",S.autoplay and C.purple or C.orange end})
    U.toggle(c,{label="Repeat Muzan",get=function() return qc().RepeatMuzan end,set=qs("RepeatMuzan"),dep=function() return qc().AutoMuzan end,depText="Enable Auto Muzan first"})
    U.toggle(c,{label="Other quest givers",desc="Generic quest/mission prompts",get=function() return qc().AutoQuest end,set=qs("AutoQuest")})
    U.toggle(c,{label="Learn target by nearby kills",desc="Off: unresolved targets are investigated via quest markers only",get=function() return qc().LearnByNearbyKills end,set=qs("LearnByNearbyKills"),
        tip="When a quest does not name its target and no marker identifies it, ON farms nearby mobs and credits the kill that advanced the counter. OFF waits for evidence."})
    U.toggle(c,{label="Auto turn-in",desc="Return to the source when the objective completes",get=function() return qc().AutoTurnIn end,set=qs("AutoTurnIn"),
        dep=function() return qc().AutoCrow or qc().AutoMuzan or qc().AutoQuest end,depText="Enable a quest source first"})
    local _,q=U.card(page,"Current quest","",{order=2,warn=function(S) local e=U.explain(S.quest.fail); return (e and e.color~=C.gold) and e.color or nil end})
    U.kv(q,"Source",function(S) return S.quest.source..(S.quest.sourceName and ("  ·  "..S.quest.sourceName) or ""),S.quest.source=="CROW" and C.purple or (S.quest.source=="MUZAN" and C.red or C.sub) end)
    U.kv(q,"State",function(S) return S.quest.state,(S.quest.fail and C.orange) or C.purple end)
    U.kv(q,"Objective",function(S) return S.quest.objective,C.text end)
    U.kv(q,"Target",function(S) if S.quest.target then return S.quest.target,C.text end; return (S.quest.objective=="KILL") and "Learning…" or "—",C.gold end)
    U.kv(q,"Confidence",function(S) local c2=S.quest.confidence; return c2,(c2=="VERIFIED" and C.green) or (c2=="HIGH" and C.green) or (c2=="TEXT MATCH" and C.cyan) or C.gold end)
    U.kv(q,"Progress",function(S) if S.quest.progress then return string.format("%d / %d",S.quest.progress,S.quest.required or 0),S.quest.stalled and C.orange or C.green end; return "—",C.gray end)
    U.bar(q,function(S) if S.quest.progress and S.quest.required and S.quest.required>0 then return S.quest.progress/S.quest.required,C.purple end; return 0,C.purple end)
    U.kv(q,"Navigation",function(S) if S.quest.nav then return S.owner=="TRAVEL" and S.travelMode or "ARRIVED",C.cyan end; return (S.target and S.owner) or "—",U.ownerColor(S.owner) end)
    U.kv(q,"Level",function(S) return S.quest.level and ("Lv "..S.quest.level) or "—",C.sub end)
    U.kv(q,"Session",function(S) return string.format("%d accepted · %d turned in",S.quest.accepted,S.quest.completed),C.sub end)
    U.warning(q,function(S) return S.quest.fail end)
    local _,pr=U.card(page,"QuestProbe","Evidence capture only. Quest reading stays UNRESOLVED until live before/after pairs map it. Snapshots are taken automatically around accept, kill and turn-in.",{order=3,collapsible=true,collapsed=true})
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
    U.kv(live,"Hover",function(S) return S.hover,(string.find(S.hover,"LOCKED",1,true) and C.green) or (S.hover=="FOLLOWING" and C.cyan) or (S.hover=="DEFENSE OVERRIDE" and C.gold) or C.gray end)
    U.kv(live,"Combo",function(S)
        local t=S.combo>0 and ("M1 ×"..S.combo) or "—"
        if S.lastSkill and S.now-S.lastSkillAt<1.5 then t=t.."  →  Skill "..tostring(S.lastSkill) end
        return t,C.text end)
    U.kv(live,"Combat state",function(S) local st=S.combatState; return st,(st=="RECOVERY" and C.red) or (st=="DEFENSE_INTERRUPT" and C.gold) or (st=="SKILL_CAST" and C.cyan) or (st=="APPROACH" and C.cyan) or (st=="IDLE" and C.gray) or C.green end)
    U.kv(live,"Next action",function(S) return S.nextAction,C.text end)
    U.kv(live,"Last skill",function(S) if not S.lastSkill then return "—",C.gray end; local v=S.lastSkillVerdict or "?"; return tostring(S.lastSkill).."  ·  "..v,(v=="VERIFIED" and C.green) or (v=="CASTING" and C.cyan) or C.orange end)
    U.kv(live,"Skills",function(S) return string.format("discovered %d  ·  sent %d  ·  verified %d",S.discovered,S.skills,S.verified),S.verified>0 and C.green or (S.skills>0 and C.orange or C.sub) end)
    U.kv(live,"Defense",function(S) return S.defense,S.defense=="READY" and C.green or C.gold end)
    U.kv(live,"Recovery",function(S) return S.recovery,(S.recovery=="STANDBY" and C.gray) or (string.find(S.recovery,"RESUMING",1,true) and C.green) or C.red end)
    U.kv(live,"M1 sent",function(S) return tostring(S.m1),C.sub end)
    U.warning(live,function(S) local f=S.skillFail; if f=="OK" or f=="IDLE" or f=="COMBO_WAIT_M1" then return nil end; return f end)
    local _,e=U.card(page,"Combat engine","One executor sends every M1 and skill.",{order=2})
    U.toggle(e,{label="Auto attack (M1)",get=function() return cfg().Combat.AutoAttack end,set=function(v) return RAVYN:SetFeature("ATTACK",v) end,
        status=function(S,on) if not on then return "OFF",C.gray end; return S.target and "FIRING" or "READY",S.target and C.green or C.sub end})
    U.toggle(e,{label="Auto skills",desc="Hotbar is discovered live; no build is hard-coded",get=function() return cfg().Combat.AutoAbilities end,set=function(v) return RAVYN:SetFeature("ABILITIES",v) end,
        status=function(S,on)
            if not on then return "OFF",C.gray end
            local x=U.explain(S.skillFail); if S.skillFail=="OK" then return "FIRING",C.green end
            if S.discovered==0 then return x and string.upper(x.title) or "NO HOTBAR",C.orange end
            return S.discovered.." FOUND",C.sub end})
    U.toggle(e,{label="Hold combo",desc="M1 chain, then decide: skill or continue",get=function() return cm().HoldCombo end,set=setc("CombatMobility.HoldCombo"),dep=function() return cfg().Combat.AutoAttack end,depText="Needs Auto attack"})
    U.segment(e,{{"2 hits",2},{"3 hits",3},{"4 hits",4},{"5 hits",5}},function() return cm().ComboLength end,setc("CombatMobility.ComboLength"),{dep=function() return cm().HoldCombo end,depText="Needs Hold combo"})
    U.toggle(e,{label="Turbo M1",desc="Fast M1 cadence",get=function() return cm().TurboM1 end,set=setc("CombatMobility.TurboM1"),dep=function() return cfg().Combat.AutoAttack end,depText="Needs Auto attack"})
    U.toggle(e,{label="Aggressive skills",desc="Shorter skill interval",get=function() return cm().AggressiveSkills end,set=setc("CombatMobility.AggressiveSkills"),dep=function() return cfg().Combat.AutoAbilities end,depText="Needs Auto skills"})
    U.toggle(e,{label="Keep combo while hit",desc="Normal damage keeps the combo; critical HP still overrides",get=function() return cm().KeepComboUnderHit end,set=setc("CombatMobility.KeepComboUnderHit"),
        tip="Survival is never disabled: critical health and learned dangerous attacks still interrupt the combo."})
    U.toggle(e,{label="Smart safety",desc="Risk engine evades on dangerous health/damage",get=function() return cfg().SmartCombat.Enabled end,set=setc("SmartCombat.Enabled")})
    local _,mit=U.card(page,"Control mitigation","Client-side, best effort. The server may reapply its own states.",{order=3,collapsible=true})
    U.toggle(mit,{label="No ragdoll",desc="Recover from ragdoll / falling / physics states",get=function() return cm().NoRagdoll end,set=function(v) RAVYN:SetConfig("CombatMobility.AntiRagdoll",v); return RAVYN:SetConfig("CombatMobility.NoRagdoll",v) end,
        status=function(S,on) return on and (tostring(S.mitigation.ragdoll or 0).." FIXED") or "OFF",on and C.green or C.gray end})
    U.toggle(mit,{label="No stun",desc="Clears observed local stun values; may be reapplied",get=function() return cm().NoStun end,set=function(v) RAVYN:SetConfig("CombatMobility.AntiStun",v); return RAVYN:SetConfig("CombatMobility.NoStun",v) end,
        status=function(S,on) return on and (tostring(S.mitigation.stun or 0).." CLEARED") or "OFF",on and C.orange or C.gray end})
    U.toggle(mit,{label="No knockback",desc="Dampens large horizontal launches outside hover",get=function() return cm().NoKnockback end,set=setc("CombatMobility.NoKnockback"),
        status=function(S,on) return on and (tostring(S.mitigation.knockback or 0).." DAMPED") or "OFF",on and C.orange or C.gray end})
    U.toggle(mit,{label="No attack slowdown",desc="Only acts on an observed local slowdown source",get=function() return cm().NoAttackSlowdown end,set=setc("CombatMobility.NoAttackSlowdown"),
        status=function(S,on) return on and "NO SOURCE" or "OFF",on and C.orange or C.gray end})
    local _,t=U.card(page,"Input test","",{order=4,collapsible=true,collapsed=true})
    U.button(t,"Send one M1",function() return RAVYN:ClientAttack() end,"accent")
    U.button(t,"Send next skill",function() return RAVYN:ClientSkill() end)
end

-- ================= LOOT =================
function U.buildLoot(page)
    local lc=function() return cfg().Loot384 end
    local lo=function(k) return function(v) return RAVYN:SetLootOption(k,v) end end
    local _,o=U.card(page,"Auto loot","Uses the game's own prompts. Collection is only counted when the drop disappears.",{order=1,warn=function(S) return S.loot.fail and C.orange or nil end})
    U.toggle(o,{label="Loot after kill",desc="Collect everything that drops from the enemy just killed",get=function() return lc().AutoLootAfterKill end,set=lo("AutoLootAfterKill")})
    U.toggle(o,{label="Loot chests",desc="Open nearby chests and collect all drops",get=function() return lc().AutoLootChests end,set=lo("AutoLootChests")})
    U.toggle(o,{label="Collect nearby loot",desc="Also take clearly-classified drops not spawned by this kill",get=function() return lc().CollectNearbyLoot end,set=lo("CollectNearbyLoot"),
        tip="Off: only drops that appeared after the kill/chest are collected. On: any nearby prompt classified as a drop."})
    local card,s=U.card(page,"Loot session","",{order=2})
    U.kv(s,"State",function(S) return S.loot.state,(S.loot.active and C.gold) or (S.loot.state=="COMPLETE" and C.green) or C.gray end)
    local detail=U.n("Frame",s,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1}); U.list(detail,8)
    U.kv(detail,"Drops detected",function(S) return tostring(S.loot.detected),C.text end)
    U.kv(detail,"Collected",function(S) return string.format("%d / %d",S.loot.collected,S.loot.detected),S.loot.collected>0 and C.green or C.sub end)
    U.bar(detail,function(S) if S.loot.detected>0 then return S.loot.collected/S.loot.detected,C.gold end; return 0,C.gold end)
    U.kv(detail,"Unverified",function(S) return tostring(S.loot.unverified),S.loot.unverified>0 and C.orange or C.sub end)
    U.kv(s,"Boss defeated",function(S) return S.loot.boss or "—",S.loot.boss and C.gold or C.gray end)
    U.kv(s,"Expected chest",function(S) return S.loot.chestExpected or "—",S.loot.chestExpected and C.text or C.gray end)
    U.kv(s,"Chest",function(S) local c2=S.loot.chest; return c2..(S.loot.chestVia and ("  ·  "..S.loot.chestVia) or ""),(c2=="OPEN_VERIFIED" and C.green) or (c2=="NOT_FOUND" or c2=="INTERACTION_UNRESOLVED" or c2=="OPEN_UNVERIFIED") and C.orange or C.sub end)
    U.kv(detail,"Attempted",function(S) return tostring(S.loot.attempted),C.sub end)
    U.kv(detail,"Remaining",function(S) return tostring(S.loot.remaining),S.loot.remaining>0 and C.gold or C.sub end)
    U.kv(s,"Last session",function(S) return S.loot.last,C.sub end)
    U.kv(s,"Interaction",function() local f=(getgenv and getgenv().fireproximityprompt) or fireproximityprompt; if type(f)=="function" then return "fireproximityprompt · PARTIAL",C.orange end; return "UNRESOLVED_GAME_BINDING",C.red end)
    U.warning(s,function(S) return S.loot.fail end)
    U.button(s,"Copy loot probe",function() return RAVYN:CopyLootProbe() end)
    local _,h=U.card(page,"Death → loot handoff","Proves whether a target death reached the loot controller.",{order=3,collapsible=true})
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
    local _,t=U.card(page,"Smart travel","Near: tween · medium: fast tween · far: one teleport per goal.",{order=2})
    U.segment(t,{{"Tight",1},{"Normal",2},{"Long",3}},function()
        local f=tc().FastTweenMaxDist; if f<=160 then return 1 elseif f<=260 then return 2 end; return 3 end,
        function(v) local map={[1]={50,150},[2]={70,220},[3]={100,400}}; RAVYN:SetConfig("TravelController.TweenMaxDist",map[v][1]); return RAVYN:SetConfig("TravelController.FastTweenMaxDist",map[v][2]) end)
    U.kv(t,"Thresholds",function() return string.format("tween ≤%d · fast ≤%d · teleport >%d",tc().TweenMaxDist,tc().FastTweenMaxDist,tc().FastTweenMaxDist),C.sub end)
    U.toggle(t,{label="Travel noclip",desc="No collision while traveling",get=function() return tc().TravelNoclip end,set=setc("TravelController.TravelNoclip"),
        tip="Collision is cached per part and restored exactly when travel ends, on Stop, respawn or Destroy."})
    local _,h=U.card(page,"Combat hover","Above and slightly behind the target; follows its height.",{order=3})
    U.toggle(h,{label="Combat hover",get=function() return cm().FlyFarmFight end,set=setc("CombatMobility.FlyFarmFight"),
        status=function(S,on) if not on then return "OFF",C.gray end; return (string.find(S.hover,"LOCKED",1,true) and "LOCKED") or S.hover,(string.find(S.hover,"LOCKED",1,true) and C.green) or C.sub end})
    U.segment(h,{{"Above","ABOVE"},{"Above behind","ABOVE_BEHIND"},{"Orbit","ORBIT_HOVER"}},function() return cm().HoverMode end,setc("CombatMobility.HoverMode"),{dep=function() return cm().FlyFarmFight end,depText="Enable Combat hover first"})
    U.segment(h,{{"Low",4},{"Normal",5.5},{"High",7.5}},function() return cm().FlyHeight end,setc("CombatMobility.FlyHeight"),{dep=function() return cm().FlyFarmFight end,depText="Enable Combat hover first"})
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
    local _,i=U.card(page,"Interface","",{order=1})
    U.toggle(i,{label="Remember settings",desc="Saved locally through executor file APIs",get=function() return cfg().UI.RememberSettings end,set=setc("UI.RememberSettings")})
    U.toggle(i,{label="Reduce motion",desc="Instant state changes, no tweens",get=function() return cfg().UI.ReducedMotion end,set=setc("UI.ReducedMotion")})
    U.button(i,"Save now",function() return RAVYN:SaveSettings() end,"accent")
    U.button(i,"Reload saved settings",function() return RAVYN:LoadSettings() end)
    U.button(i,"Delete saved settings",function() return RAVYN:DeleteSavedSettings() end,"danger")
    local _,w=U.card(page,"World","",{order=2})
    U.segment(w,{{"Walk",16},{"Swift",22},{"Fast",28}},function() local v=cfg().Movement.Speed; if v<=17 then return 16 elseif v<=23 then return 22 end; return 28 end,
        function(v) local r=RAVYN:SetConfig("Movement.Speed",v); if r.ok then RAVYN:SetConfig("Movement.SpeedEnabled",v~=16) end; return r end)
    U.toggle(w,{label="NPC ESP",get=function() return cfg().Intelligence.ESP.NPC end,set=function(v) return RAVYN:SetESP("NPC",v) end})
    U.toggle(w,{label="Boss ESP",get=function() return cfg().Intelligence.ESP.Boss end,set=function(v) return RAVYN:SetESP("Boss",v) end})
    U.toggle(w,{label="Anti-AFK",get=function() return cfg().Intelligence.AntiAFK end,set=function(v) return RAVYN:SetAntiAFK(v) end})
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
    -- Learn Action
    local _,la=U.card(page,"Learn action","Pick what you are about to do, press Start, do it once by hand in the game, then press Stop. RAVYN records what changed and which prompt/button/key you used. Evidence only — nothing becomes verified automatically.",{order=1})
    local selected={PR and PR.presets[1][1] or "Custom action",PR and PR.presets[1][2] or "OTHER"}
    local grid=U.n("Frame",la,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
    U.n("UIGridLayout",grid,{CellSize=UDim2.new(.333,-6,0,30),CellPadding=UDim2.fromOffset(6,6),SortOrder=Enum.SortOrder.LayoutOrder})
    local chips={}
    for i,p in ipairs(PR and PR.presets or {}) do
        local b=U.n("TextButton",grid,{BackgroundColor3=C.card,Text=p[1],TextColor3=C.sub,TextSize=11,Font=U.F.semi,AutoButtonColor=false,BorderSizePixel=0,LayoutOrder=i,TextTruncate=Enum.TextTruncate.AtEnd})
        U.round(b,8); chips[i]={b=b,p=p}
        table.insert(RAVYN._connections,b.Activated:Connect(function() if PR.recording then U.toast("Stop the current recording first","warn"); return end; selected={p[1],p[2]} end))
    end
    U.addRefresh(function()
        for _,c in ipairs(chips) do
            local on=c.p[1]==selected[1]
            U.setColor(c.b,"BackgroundColor3",on and C.goldDim or C.card); U.setColor(c.b,"TextColor3",on and C.gold or C.sub)
        end
    end)
    U.kv(la,"Selected",function() return selected[1].."  ·  "..selected[2],C.text end)
    local rec=U.button(la,"Start recording",function()
        if PR.recording then return RAVYN:LearnActionEnd() end
        return RAVYN:LearnActionBegin(selected[1],selected[2])
    end,"accent")
    U.addRefresh(function()
        if PR.recording then U.setText(rec,string.format("Stop recording · %s · %.0fs",PR.recording.label,os.clock()-PR.recording.at)); U.setColor(rec,"TextColor3",C.red)
        else U.setText(rec,"Start recording"); U.setColor(rec,"TextColor3",C.gold) end
    end)
    U.kv(la,"Last evidence",function()
        local r=PR and PR.records[#PR.records]; if not r then return "none yet",C.gray end
        return r.actionName.." · "..r.confidence..(r.file and " · saved to RAVYN/Probes" or ""),(r.confidence=="HIGH" and C.green) or (r.confidence=="MEDIUM" and C.orange) or C.sub end)
    U.kv(la,"Interaction",function()
        local r=PR and PR.records[#PR.records]; if not r then return "—",C.gray end; return r.interactionCandidate,C.text end)
    U.kv(la,"Changes",function()
        local r=PR and PR.records[#PR.records]; if not r then return "—",C.gray end
        return string.format("GUI %d · world %d · values %d",r.guiChanges,r.worldChanges,r.valueChanges),C.sub end)
    U.button(la,"Copy last evidence",function() return RAVYN:CopyLearnActionReport() end)
    -- Game systems
    local _,gs=U.card(page,"Game systems","What RAVYN understands about each Slayers 2 activity. REFERENCE facts come from guides and are never used as bindings.",{order=2})
    for _,k in ipairs(GK and GK.order or {}) do
        U.kv(gs,GK.systems[k].title,function()
            local s=GK.systems[k]; return s.status..(s.evidence>0 and ("  ·  "..s.evidence.." evidence") or ""),statusColor(s.status) end)
    end
    -- Player progress + world
    local _,pp=U.card(page,"Player progress","Verified reads only. Unknown values stay unresolved; possible data fields are listed as candidates.",{order=3,collapsible=true})
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
do local ok=runChunk("UI384_Mount.lua",[==========[local G=(getgenv and getgenv()) or _G
local CTX=G.__RAVYN_CTX
local RAVYN=CTX["RAVYN"]
local U=CTX["UI384"]
local C=U.C
local UIS=game:GetService("UserInputService")
local PAGES={
    {"Home","◆",{"home","dashboard","status"},"buildHome"},
    {"Auto Play","◎",{"auto","play","master","mode","boss rotation","scheduler"},"buildAutoPlay"},
    {"Quests","◇",{"quest","crow","muzan","level","turn"},"buildQuests"},
    {"Farm","◉",{"farm","mob","target","npc","aura","radius"},"buildFarm"},
    {"Combat","✦",{"combat","m1","skill","combo","ragdoll","stun","knockback","mitigation"},"buildCombat"},
    {"Loot","◈",{"loot","chest","drop"},"buildLoot"},
    {"Travel","➤",{"travel","hover","noclip","teleport","tween","place","height"},"buildTravel"},
    {"Intelligence","✧",{"face","dodge","guard","threat","learn","loadout","skills"},"buildIntelligence"},
    {"Research","⌬",{"research","probe","learn","evidence","crow","muzan","training","knowledge","progress"},"buildResearch"},
    {"Dungeon","▣",{"dungeon","ouwigahara","card"},"buildDungeon"},
    {"Diagnostics","⌘",{"diag","log","feed","boss","debug","error"},"buildDiagnostics"},
    {"Settings","⚙",{"settings","esp","afk","speed","save","motion"},"buildSettings"},
}
local BADGES={
    Quests=function(S) local e=U.explain(S.quest.fail); if S.questEnabled and not S.autoplay then return C.orange end; return (e and e.color~=C.gold and e.color~=C.cyan) and e.color or nil end,
    Combat=function(S) if not RAVYN.Config.Combat.AutoAbilities then return nil end; local e=U.explain(S.skillFail); return (e and (e.color==C.red or e.color==C.orange)) and e.color or nil end,
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
    local function sizeFor() local v=(cam and cam.ViewportSize) or Vector2.new(1600,900); return math.floor(math.clamp(v.X*.62,760,1120)),math.floor(math.clamp(v.Y*.78,500,720)) end
    local W,H=sizeFor()
    local shadow=U.n("Frame",gui,{Size=UDim2.fromOffset(W+24,H+24),Position=UDim2.new(.5,-(W+24)/2,.5,-(H+24)/2+4),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.72,BorderSizePixel=0}); U.round(shadow,28)
    -- v3.8.4.3: plain Frame. A window-sized CanvasGroup re-renders its whole texture on every descendant change,
    -- which flickered under combat telemetry. Open/hide animate UIScale only.
    local win=U.n("Frame",gui,{Size=UDim2.fromOffset(W,H),Position=UDim2.new(.5,-W/2,.5,-H/2),BackgroundColor3=C.bg,BorderSizePixel=0,Active=true,ClipsDescendants=true})
    U.round(win,20); U.stroke(win,C.line,1,.15)
    U.n("UISizeConstraint",win,{MinSize=Vector2.new(720,480)})
    local scale=U.n("UIScale",win,{Scale=.96})
    U.anim(scale,.3,{Scale=1})
    -- header
    local top=U.n("Frame",win,{Size=UDim2.new(1,0,0,60),BackgroundColor3=C.panel,BorderSizePixel=0,Active=true})
    U.n("Frame",top,{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=C.line,BorderSizePixel=0})
    U.label(top,"RAVYN",20,C.text,U.F.bold,{Size=UDim2.fromOffset(90,60),Position=UDim2.fromOffset(20,0),TextWrapped=false})
    local gchip=U.n("Frame",top,{Size=UDim2.fromOffset(260,28),Position=UDim2.fromOffset(112,16),BackgroundColor3=C.raised,BorderSizePixel=0}); U.round(gchip,14)
    local gdot=U.n("Frame",gchip,{Size=UDim2.fromOffset(8,8),Position=UDim2.new(0,12,.5,-4),BackgroundColor3=C.gray,BorderSizePixel=0}); U.round(gdot,4)
    local gtext=U.label(gchip,"READY",11,C.text,U.F.bold,{Size=UDim2.new(1,-30,1,0),Position=UDim2.fromOffset(26,0),TextWrapped=false,TextTruncate=Enum.TextTruncate.AtEnd})
    local ver=U.label(top,"",11,C.faint,U.F.body,{Size=UDim2.fromOffset(200,60),Position=UDim2.new(1,-300,0,0),TextXAlignment=Enum.TextXAlignment.Right,TextWrapped=false})
    local function topBtn(txt,x) local b=U.n("TextButton",top,{Size=UDim2.fromOffset(34,34),Position=UDim2.new(1,x,.5,-17),BackgroundColor3=C.card,Text=txt,TextColor3=C.text,TextSize=16,Font=U.F.bold,AutoButtonColor=false,BorderSizePixel=0}); U.round(b,10)
        table.insert(RAVYN._connections,b.MouseEnter:Connect(function() U.anim(b,.12,{BackgroundColor3=C.raised}) end)); table.insert(RAVYN._connections,b.MouseLeave:Connect(function() U.anim(b,.14,{BackgroundColor3=C.card}) end)); return b end
    local hideB=topBtn("—",-84); local closeB=topBtn("×",-44)
    U.addRefresh(function(S) U.setText(gtext,S.global); U.setColor(gtext,"TextColor3",S.globalColor); U.setColor(gdot,"BackgroundColor3",S.globalColor); U.setColor(gchip,"BackgroundColor3",U.dimOf(S.globalColor)); U.setText(ver,"v"..S.version) end)
    -- sidebar
    local side=U.n("Frame",win,{Size=UDim2.new(0,184,1,-60),Position=UDim2.fromOffset(0,60),BackgroundColor3=C.panel,BorderSizePixel=0})
    local search=U.n("TextBox",side,{Size=UDim2.new(1,-24,0,34),Position=UDim2.fromOffset(12,12),BackgroundColor3=C.card,Text="",PlaceholderText="Search or command…",PlaceholderColor3=C.faint,TextColor3=C.text,TextSize=12,Font=U.F.body,ClearTextOnFocus=false,BorderSizePixel=0,TextXAlignment=Enum.TextXAlignment.Left}); U.round(search,9); U.pad(search,10,10,0,0)
    local nav=U.n("ScrollingFrame",side,{Size=UDim2.new(1,-16,1,-60),Position=UDim2.fromOffset(8,56),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=0,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()}); U.list(nav,3)
    local marker=U.n("Frame",side,{Size=UDim2.fromOffset(3,22),Position=UDim2.fromOffset(8,70),BackgroundColor3=C.gold,BorderSizePixel=0,ZIndex=3}); U.round(marker,2)
    -- content
    local content=U.n("Frame",win,{Size=UDim2.new(1,-184,1,-60),Position=UDim2.fromOffset(184,60),BackgroundTransparency=1})
    local heading=U.label(content,"Home",20,C.text,U.F.bold,{Size=UDim2.new(1,-48,0,28),Position=UDim2.fromOffset(24,16),TextWrapped=false})
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
        if prev and prev~=groups[name] then prev.Visible=false end
        local g=groups[name]; g.Visible=true; g.Position=UDim2.fromOffset(8,0)
        U.anim(g,.2,{Position=UDim2.fromOffset(0,0)})
        U.runPage(name) -- bring the newly shown page up to date once
        for n2,b in pairs(U.navButtons) do U.setColor(b,"TextColor3",n2==name and C.text or C.sub,.14); U.setColor(b,"BackgroundTransparency",n2==name and 0 or 1,.14) end
        task.defer(function() local b=U.navButtons[name]; if b then U.anim(marker,.24,{Position=UDim2.fromOffset(8,b.AbsolutePosition.Y-side.AbsolutePosition.Y+7)}) end end)
    end
    U.show=show
    for i,def in ipairs(PAGES) do
        local name=def[1]
        local g=U.n("Frame",host,{Name=name,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false})
        local sc=U.n("ScrollingFrame",g,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.faint,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollingDirection=Enum.ScrollingDirection.Y})
        U.list(sc,12); U.pad(sc,2,8,2,24)
        groups[name]=g; U.pages[name]=sc
        local b=U.n("TextButton",nav,{Size=UDim2.new(1,0,0,36),BackgroundColor3=C.raised,BackgroundTransparency=1,Text="   "..def[2].."   "..name,TextColor3=C.sub,TextSize=13,Font=U.F.semi,TextXAlignment=Enum.TextXAlignment.Left,AutoButtonColor=false,BorderSizePixel=0,LayoutOrder=i}); U.round(b,9)
        local badge=U.n("Frame",b,{Size=UDim2.fromOffset(8,8),Position=UDim2.new(1,-18,.5,-4),BackgroundColor3=C.orange,BorderSizePixel=0,Visible=false}); U.round(badge,4)
        U.navButtons[name]=b; U.badges[name]=badge
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
        for _,def in ipairs(PAGES) do
            local hit=string.find(string.lower(def[1]),q,1,true)~=nil
            if not hit then for _,k in ipairs(def[3]) do if string.find(k,q,1,true) then hit=true; break end end end
            if hit then table.insert(out,def[1]) end
        end
        return out
    end
    table.insert(RAVYN._connections,search:GetPropertyChangedSignal("Text"):Connect(function()
        local q=string.lower(search.Text or ""); local set={}
        if q~="" then for _,n2 in ipairs(matches(q)) do set[n2]=true end end
        for n2,b in pairs(U.navButtons) do b.Visible=(q=="") or set[n2]==true end
    end))
    table.insert(RAVYN._connections,search.FocusLost:Connect(function(enter)
        if not enter then return end
        local q=string.lower(search.Text or "")
        if q=="stop" or q=="stop everything" then pcall(function() RAVYN:SetAutoPlay(false); RAVYN:Stop() end); U.toast("Stopped","success")
        else local m=matches(q); if m[1] then show(m[1]) end end
        search.Text=""
    end))
    -- hide / restore / close / drag
    local pill=U.n("TextButton",gui,{Size=UDim2.fromOffset(132,40),Position=UDim2.new(0,20,.5,-20),BackgroundColor3=C.panel,Text="",AutoButtonColor=false,Visible=false,BorderSizePixel=0}); U.round(pill,20); U.stroke(pill,C.line,1,.2)
    local pdot=U.n("Frame",pill,{Size=UDim2.fromOffset(8,8),Position=UDim2.new(0,16,.5,-4),BackgroundColor3=C.gray,BorderSizePixel=0}); U.round(pdot,4)
    U.label(pill,"RAVYN",13,C.gold,U.F.bold,{Size=UDim2.new(1,-40,1,0),Position=UDim2.fromOffset(32,0),TextWrapped=false})
    local busy=false
    local function setHidden(v)
        if busy or U.hidden==v then return end; busy=true
        if v then
            U.anim(scale,.16,{Scale=.96})
            task.delay(.19,function() win.Visible=false; shadow.Visible=false; U.hidden=true; pill.Visible=true; busy=false end)
        else
            U.hidden=false; pill.Visible=false; win.Visible=true; shadow.Visible=true; scale.Scale=.96
            U.anim(scale,.22,{Scale=1}); U.runPage(U.activePage); task.delay(.23,function() busy=false end)
        end
    end
    table.insert(RAVYN._connections,hideB.Activated:Connect(function() setHidden(true) end))
    table.insert(RAVYN._connections,pill.Activated:Connect(function() setHidden(false) end))
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
                pdot.BackgroundColor3=S.globalColor
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
print("RAVYN V3.8.5 GAME KNOWLEDGE | LEARN ACTION PROBES | EVIDENCE-FIRST QUESTS | v3.8.4.3 STABILITY")
mountUI()
CTX["env"]=env
CTX["previous"]=previous
return RAVYN]==========]); if not ok then return end; if res then CTX.RAVYN=res end end
if not CTX.RAVYN then diag("RAVYN BOOT FAILED · RUNTIME MISSING",true); return end
if not CTX.RAVYN._gui then
    local detail="UI_NOT_MOUNTED"
    local entries=CTX.RAVYN.Logger and CTX.RAVYN.Logger.entries
    if entries and #entries>0 then detail=detail.." · "..tostring(entries[#entries].message or "") end
    diag("RAVYN v3.8.5 BOOT PASS · "..detail,true)
    return CTX.RAVYN
end
diag("RAVYN v3.8.5 READY · GAME KNOWLEDGE",false)
task.delay(5,function() if diagGui then pcall(function() diagGui:Destroy() end) end end)
return CTX.RAVYN
