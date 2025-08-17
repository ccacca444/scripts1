--可以单独运行

当地的FOV=当地的
当地的maxDistance=当地的
当地的maxTransparency=当地的
当地的teamCheck=假的
当地的墙检查=正确
当地的aimPart="头" aimPart = --“躯干”

当地的RunService=game:GetService("运行服务" RunService = game:GetService(
当地的玩家=游戏：GetService("玩家" Players = game:GetService(
当地的Cam=game.Workspace.CurrentCamera

当地的FOVring=Drawing.new("圆圈" FOVring = Drawing.new(
FOVring.Visible=正确
FOVring.Thickness = 2
FOVring.Color = Color3.fromRGB(128, 0, 128)
FOVring.Filled=假的
FOVring.Radius = fov
FOVring.Position = Cam.ViewportSize / 2

当地的 功能updateDrawings()
    FOVring.Position = Cam.ViewportSize / 2
结束

当地的 功能lookat(目标)
    当地的lookVector=(目标-Cam.CFrame.Position).Unit
    当地的newCFrame=CFrame.new(Cam.CFrame.Position，Cam.CFrame.Position+lookVector)
    Cam.CFrame = newCFrame
结束

当地的 功能calculateTransparency(距离)
    返回 (
结束

当地的 功能isPlayerAlive(播放器)
    当地的character=player.Character
    返回性格和字符：FindFirstChild("类人") 和性格.类人.健康>和
结束

当地的 功能isPlayerVisibleThroughWalls(播放器，trg_part)
    如果 不墙方格然后
        返回 正确
    结束

    当地的localPlayerCharacter=players.LocalPlayer.Character
    如果 不localPlayerCharacter然后
        返回 假的
    结束

    当地的part=player.Character和player.Character:FindFirstChild(trg_part)
    如果 不部分然后
        返回 假的
    结束

    当地的Ray=Ray.new(Cam.CFrame.Position，part.Position-Cam.CFrame.Position)
    当地的命中，_=工作区：FindPartOnRayWithIgnoreList(ray，{localPlayerCharacter})

    如果打击和命中：IsDescendantOf(player.Character)然后
        返回 正确
    结束

    -- Fallback to a nearby position if the direct ray doesn't hit
    当地的方向=(零件位置-凸轮框架位置).单位
    当地的nearRay=Ray.new(Cam.CFrame.Position+direction*local，方向*最大距离)
    当地的nearHit，_=工作区：FindPartOnRayWithIgnoreList(nearRay，{localPlayerCharacter})

    返回nearHit和nearHit:IsDescendantOf(player.Character)
结束

当地的 功能getClosestPlayerInFOV()
    当地的最近的=零
    当地的last=math.huge
    当地的playerMousePos=Cam.ViewportSize/local
    当地的localPlayer=players.LocalPlayer

    为_，播放器在……内iPairs(播放器：GetPlayers())做
        如果player~=localPlayer和 (不teamCheck或player.Team~=localPlayer.Team)和isPlayerAlive(播放器)然后
            当地的人形=玩家.角色和player.Character:FindFirstChild("类人" humanoid = player.Character 
            当地的part=player.Character和player.Character：查找FirstChild(aimPart)
            如果类人的和部分然后
                当地的EPOS，isVisible=Cam:WorldToViewportPoint(零件位置)
                当地的距离=(Vector2.new(ePos.x，ePos.y)-playerMousePos).幅度

                如果距离<上次和is可见和距离<fov和距离<maxDistance和isPlayerVisibleThroughWalls(播放器、aimPart)然后
                    last = distance
                    nearest = player
                结束
            结束
        结束
    结束

    返回最近的
结束

RunService.RenderSteped:Connect(功能()
    updateDrawings()
    当地的closest=getClosestPlayerInFOV()
    如果最靠近的和closest.Character:FindFirstChild(aimPart)然后
        lookAt(closest.Character[aimPart].Position)
    结束
    
    如果最靠近的然后
        当地的part=最近.字符[aimPart]
        当地的EPOS，isVisible=Cam:WorldToViewportPoint(零件位置)
        当地的距离=(Vector2.new(ePos.x，ePos.y)-(Cam.ViewportSize/local).震级
        FOVring.Transparency = calculateTransparency(distance)
    其他
        FOVring.Transparency = maxTransparency
    结束
结束)
