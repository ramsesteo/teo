#
# Copyright (C) 2021-2022 by TeamYukki@Github, < https://github.com/TeamYukki >.
#
# This file is part of < https://github.com/TeamYukki/YukkiMusicBot > project,
# and is released under the "GNU v3.0 License Agreement".
# Please see < https://github.com/TeamYukki/YukkiMusicBot/blob/master/LICENSE >
#
# All rights reserved.

import asyncio
import os

import speedtest
import wget
from pyrogram import filters

from strings import get_command
from YukkiMusic import app
from YukkiMusic.misc import SUDOERS

# Commands
SPEEDTEST_COMMAND = get_command("SPEEDTEST_COMMAND")


def testspeed(m):
    try:
        test = speedtest.Speedtest()
        test.get_best_server()
        m = m.edit("Running Download SpeedTest")
        test.download()
        m = m.edit("Upload SpeedTest'i Çalıştırma")
        test.upload()
        test.results.share()
        result = test.results.dict()
        m = m.edit("SpeedTest Sonuçlarını Paylaşma")
        path = wget.download(result["share"])
    except Exception as e:
        return m.edit(e)
    return result, path


@app.on_message(filters.command(SPEEDTEST_COMMAND) & SUDOERS)
async def speedtest_function(client, message):
    m = await message.reply_text("Hız testi")
    loop = asyncio.get_event_loop()
    result, path = await loop.run_in_executor(None, testspeed, m)
    output = f"""**Hız Testi Sonuçları**
    
<u>**Server:**</u>
**__İSİM:__**  **EgoistBEY**
**__Ülke:__** {result['server']['country']}, {result['server']['cc']}
**__Gecikme:__** {result['server']['latency']}  
**__Ping:__** {result['ping']}"""
    msg = await app.send_photo(
        chat_id=message.chat.id, photo=path, caption=output
    )
    os.remove(path)
    await m.delete()
