local frequency = settings.get("knijn.fancyplayer.frequency",65500)
local pid = settings.get("knijn.fancyplayer.pid",2024)

local radios = {}


local modem = peripheral.find("modem")
dfpwm = require("cc.audio.dfpwm")
local leftSpeaker = settings.get("knijn.fancyplayer.leftSpeaker", "left")
local rightSpeaker = settings.get("knijn.fancyplayer.rightSpeaker", "right")
local monoSpeaker = settings.get("knijn.fancyplayer.monoSpeaker","right")
local mono = settings.get("knijn.fancyplayer.mono",false)


local mon = peripheral.find("monitor")
local decoders={left=dfpwm.make_decoder(),right=dfpwm.make_decoder()}

mon.setTextScale(0.5)

local function scanner()
  while true do
    for i=65500,65535 do
      modem.open(i)
    end

    local function channelAdder()
      while true do
        local event, side, freq, pidmsg, msg, dist = os.pullEvent("modem_message")
        if type(msg) == "string" and msg ~= "PING" then
          print("unpacking...")
          local unpack={string.unpack("s1s1",msg)}
          print("done...")
          local channelName = unpack[1]
          local programName = unpack[2]
          local OKtoAdd = true
          for i,o in pairs(radios) do
            if o.frequency == frequency and o.pid == pidmsg then
              radios[i].programName = programName
              radios[i].channelName = channelName
              OKtoAdd = false
            end
          end
          if OKtoAdd then
            local t = {programName = programName, channelName = channelName, frequency = freq, pid = pidmsg}
            table.insert(radios,t)
          end
        end
      end
    end

    local function timer()
      sleep(3)
    end
    parallel.waitForAny(timer,channelAdder)
    for i=65500,65535 do
      modem.close(i)
    end
    modem.open(frequency)
  end
end

local function touchListener()
  while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    if radios[y] then
      frequency = radios[y].frequency
      pid = radios[y].pid
      settings.set("knijn.fancyplayer.frequency",frequency)
      settings.set("knijn.fancyplayer.pid",pid)
      settings.save()
    end
  end
end

local function draw()
  while true do
    mon.setBackgroundColor(colors.white)
    mon.setTextColor(colors.black)
    mon.clear()
    local channelName = "nil"
    local programName = "nil"
    for i,o in pairs(radios) do
      mon.setCursorPos(1,i)
      if o.frequency == frequency and o.pid == pid then
        mon.setBackgroundColor(colors.pink)
        channelName = o.channelName
        programName = o.programName
      else
        mon.setBackgroundColor(colors.white)
      end
      mon.write(o.frequency .. "|" .. o.pid .. " - " .. o.channelName)
    end
    local xSize, ySize = mon.getSize()
    mon.setBackgroundColor(colors.white)
    mon.setCursorPos(1,ySize-3)
    mon.write("Tuned Channel: " .. frequency .. "|" .. pid)
    mon.setCursorPos(1,ySize-1)
    mon.write(channelName)
    mon.setCursorPos(1,ySize)
    mon.write(programName)

    sleep(0.2)
  end
end

local function player()
  while true do
  local event, side, freq, pidmsg, msg, dist = os.pullEvent("modem_message")
  if freq == frequency and pidmsg == pid then
    local unpack={string.unpack("s1s1s2",msg)}
    local leftSample,rightSample=unpack[3]:sub(1,6000),unpack[3]:sub(6001,12000)
    local leftAudio,rightAudio=decoders.left(leftSample),decoders.right(rightSample)
    if not mono then
      peripheral.call(leftSpeaker,"playAudio",leftAudio)
      peripheral.call(rightSpeaker,"playAudio",rightAudio)
    end

    if mono then
      local monoAudio = {}
      for i,o in pairs(leftAudio) do
        monoAudio[i] = leftAudio[i] / 2 + rightAudio[i] / 2
      end

      peripheral.call(monoSpeaker,"playAudio",monoAudio)
    end
  end
end
end

parallel.waitForAny(draw,scanner,touchListener,player)