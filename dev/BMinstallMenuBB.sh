#!/bin/bash
########################################################################################

#kate: bom on; end-of-line style:unix;


# pip install --user python2-pythondialog  # bitmessagemain.py --curses # works in xterm but does not  work in Konsole



#     https://pastebin.com/raw/HrLtCKaj

#     https://pastebin.com/HrLtCKaj

#     https://pastebin.com/print/HrLtCKaj

#  <script src="https://pastebin.com/embed_js/HrLtCKaj"></script>


#  Iframe Embedding (you can set the frame height by adding the CSS value 'height:100px;' for example)
# <iframe src="https://pastebin.com/embed_iframe/HrLtCKaj" style="border:none;width:100%"></iframe>




#     usage example:       menu     pwd whoami ls ps

#     giving you a menu with 4 options to execute in bash shell / Konsole



# call in bash as:    . menu1    # if  menu1  is the file name with this script in it
# usage e.g.:
# menu ls  "ls -l"  "echo  list dir ; clear ; ls -la "   clear
# q, Q or 0 or empty_string i.e. ENTER-key alone     always exits the menu


# click-launch from Dolphin file-manager in KDE: associate shell script  open-action command:  konsole -e %f
# under right-cick,  FILE TYPE OPTIONS,  ...  advanced option, do not tag "run in Terminal"
# so you get a  "open action"  rather than an "execute action" , but it does what you expect.


# to set as a bash lib func  : copy the text  between the upper and lower ###### lines into your ~/.bashrc file







ibitboard()
{
clear
echo "install of bitboard web thingy"
pushd .

# unalias cp
# cp

mkdir    bb
cd     ./bb


(
cat <<'EOFherefile'
import base64
import json
import logging as log
import time
import traceback
import xmlrpclib
from threading import Thread

import config
from chan_objects import ChanBoard
from chan_objects import ChanPost


def getBitmessageEndpoint():
    username = "aa"        #config.getBMConfig("apiusername")
    password = "aa"        #config.getBMConfig("apipassword")
    host =     "127.0.1"   #config.getBMConfig("apiinterface")
    port =     "8442"      #config.getBMConfig("apiport")
#   return "http://"+username+":"+password+"@"+host+":"+port+"/"
    return "http://aa:aa@127.0.0.1:8442/"

'''

this is file  /bitboard-master/bitmessage_gateway.py

lauch as daemon and curses, then the missing Qt4 stuff does not matter.

python2 bitmessagemain.py --curses






                                                   http://localhost:8080

                                  kioclient5 exec 'http://localhost:8080'


daemon = true
dontconnect = false


maxdownloadrate = 33
maxoutboundconnections = 2
maxuploadrate = 33



apienabled = true
apiusername = aa
apipassword = aa
apiinterface = 127.0.0.1
apiport = 8442






'''


class BitMessageGateway(Thread):
    def __init__(self):
        super(BitMessageGateway, self).__init__()
        self._postsById = {}
        self._boardByChan = {}
        self._chanDict = {}
        self._refresh = True
        self._api = xmlrpclib.ServerProxy(getBitmessageEndpoint())

    def run(self):
        while True:
            try:
                print "Updating bitmessage info."
                self.updateChans()
                self.updateChanThreads()

                print `len(self._postsById)` + " total messages " + `len(self._chanDict)` + " total chans."

                for i in range(0, config.bm_refresh_interval):
                    time.sleep(i)
                    if self._refresh:
                        self._refresh = False
                        break
            except Exception as e:
                log.error("Exception in gateway thread: " + `e`)
                time.sleep(config.bm_refresh_interval)

    def getChans(self):
        return self._chanDict

    def deleteMessage(self, chan, messageid):
        try:
            board = self._boardByChan[chan]
            post = self._postsById[messageid]
            board.deletePost(post)
            del self._postsById[messageid]
        except Exception as e:
            print "Exception deleting post: " + `e`
            traceback.print_exc()
        return self._api.trashMessage(messageid)

    def deleteThread(self, chan, threadid):
        try:
            board = self._boardByChan[chan]
            thread = board.getThread(threadid)
            if thread:
                threadposts = thread.getPosts()
                for post in threadposts:
                    self.deleteMessage(chan, post.msgid)
            board.deleteThread(threadid)
        except Exception as e:
            print "Exception deleting thread: " + repr(e)
            traceback.print_exc()
        return "Thread [" + repr(threadid) + "] deleted."

    def updateChans(self):
        chans = {}
        try:
            straddr = self._api.listAddresses()
            addresses = json.loads(straddr)['addresses']
            for jaddr in addresses:
                if jaddr['chan'] and jaddr['enabled']:
                    chan_name = jaddr['label']
                    chans[chan_name] = jaddr['address']
        except Exception as e:
            log.error("Exception getting channels: " + `e`)
            traceback.print_exc()

        self._chanDict = dict(self._chanDict.items() + chans.items())

    def getChanName(self, chan):
        for label, addr in self._chanDict.iteritems():
            if addr == chan:
                return label

    def getImage(self, imageid):
        return self._postsById[imageid].image

    def updateChanThreads(self):
        strmessages = self._api.getAllInboxMessageIDs()
        messages = json.loads(strmessages)['inboxMessageIds']
        for message in messages:
            messageid = message["msgid"]

            if messageid in self._postsById:
                continue

            strmessage = self._api.getInboxMessageByID(messageid)
            jsonmessages = json.loads(strmessage)['inboxMessage']

            if len(jsonmessages) <= 0:
                continue

            chan = jsonmessages[0]['toAddress']
            post = ChanPost(chan, jsonmessages[0])

            if chan not in self._boardByChan:
                self._boardByChan[chan] = ChanBoard(chan)

            self._postsById[messageid] = post
            chanboard = self._boardByChan[chan]
            chanboard.addPost(post)

    def getThreadCount(self, chan):
        if chan not in self._boardByChan:
            return 0
        return self._boardByChan[chan].getThreadCount()

    def getChanThreads(self, chan, page=1):
        if chan not in self._boardByChan:
            return []
        board = self._boardByChan[chan]

        thread_start = int((int(page) - 1) * config.threads_per_page)
        thread_end = int(int(page) * config.threads_per_page)

        return board.getThreads(thread_start, thread_end)

    def getChanThread(self, chan, thread_id):
        if chan not in self._boardByChan:
            return None

        board = self._boardByChan[chan]

        return board.getThread(thread_id)

    def submitPost(self, chan, subject, body, image):
        subject = subject.encode('utf-8').strip()
        subjectdata = base64.b64encode(subject)

        msgdata = body.encode('utf-8').strip()

        if image:
            imagedata = base64.b64encode(image)
            msgdata += "\n\n<img src=\"data:image/jpg;base64," + imagedata + "\">"

        msg = base64.b64encode(msgdata)

        self._refresh = True
        return self._api.sendMessage(chan, chan, subjectdata, msg)

    def joinChan(self, passphrase):
        self._refresh = True

        try:
            result = self._api.createChan(base64.b64encode(passphrase))
        except Exception as e:
            result = repr(e)

        return result

    def getAPIStatus(self):
        try:
            result = self._api.add(2, 2)
        except Exception as e:
            return repr(e)
        if result == 4:
            return True
        return result

gateway_instance = BitMessageGateway()
gateway_instance.start()
EOFherefile
) > bitmessage_gateway.py

git clone https://github.com/michrob/bitboard  #  modded 8442
cd bitboard/


mv    bitmessage_gateway.py  bitmessage_gateway___ORIG.py
mv ../bitmessage_gateway.py  .
#                                  github version breaks too much


echo '#!/usr/bin/env python2 '  >  bb.py
chmod +x                           bb.py
cat ./bitboard.py               >> bb.py



python2 -m pip install --user  -r requirements.txt
# mod gateway aa:aa

# python2 ./bitmessagemain.py --curses
# python2   bitboard.py                   &
          ./bb.py                         &
#                                                  env might be elsewhere
# python2 ./bb.py                         &
sleep 1.1 # wait until web server is ready
kioclient5 exec 'http://localhost:8080'   &
popd
}








menu()
{
local IFS=$' \t\n'
local num n=1 opt item cmd

clear

## Use default setting of IFS,  Loop though the command-line arguments
echo
for item
do
  printf " %3d. %s\n" "$n" "${item%%:*}"
  n=$(( $n + 1 ))
done

## If there are fewer than 10 items, set option to accept key without ENTER
echo
if [ $# -lt 10 ]
then
  opt=-sn1
else
  opt=
fi

read -p "ENTER quits menu - please choose  1 to $# ==> " $opt num   ## Get response from user

## Check that user entry is valid
case $num in
   [qQ0]   | "" ) clear ; return ;;   ## q, Q or 0 or "" exits
  *[!0-9]* | 0* )                     ## invalid entry

  printf "\aInvalid menu choice : %s\n" "$num" >&2
  return 1
  ;;
esac

echo
if     [ "$num" -le "$#" ]  ## Check that number is <= to the number of menu items
then
  eval  ${!num}             ## eval  "${!num#*:}"  # Execute it using indirect expansion,  breaking stuff  :-(
else
  printf "\aInvalid menu choice: %s\n" "$num" >&2
  return 1
fi
}
##############################################################################################








#-----------------------------------------------------------
# "Here-document" containing nice standard keys.dat with 3 chans and 1 nuked ID / pml , dropped into thwe cwd, i.e.  .

# note that a nuked address is kind of useless , since its key was published. It still is kinda broadcast fun though.
# You have no privacy using a nuked key -
# much like you don't have privacy while using a key which someone has stolen from you.

(
cat <<'EOFherefile'

[bitmessagesettings]
apienabled = true
apiport = 8442
apiinterface = 127.0.0.1
apipassword = aa
apiusername = aa
blackwhitelist = black
daemon = true
defaultnoncetrialsperbyte = 1000
defaultpayloadlengthextrabytes = 1000
dontconnect = false
dontsendack = False
hidetrayconnectionnotifications = True
identiconsuffix = AAAAAAAAAAAA
keysencrypted = false
maxacceptablenoncetrialsperbyte = 20000000000
maxacceptablepayloadlengthextrabytes = 20000000000
maxdownloadrate = 55
maxoutboundconnections = 1
maxuploadrate = 55
messagesencrypted = false
minimizeonclose = false
minimizetotray = False
namecoinrpchost = localhost
namecoinrpcpassword =
namecoinrpcport = 8336
namecoinrpctype = namecoind
namecoinrpcuser =
onionbindip = 127.0.0.1
onionhostname = AAAAAAAAAAAAAAAA.onion
onionport = 8448
opencl = None
port = 8444
replybelow = False
sendoutgoingconnections = True
settingsversion = 10
showtraynotifications = False
smtpdeliver =
socksauthentication = False
sockshostname = 127.0.0.1
sockslisten = False
sockspassword =
socksport = 9150
socksproxytype = none
socksusername =
startintray = False
startonlogon = False
stopresendingafterxdays = 5.0
stopresendingafterxmonths = 5.0
timeformat = %%a, %%d %%b %%Y  %%H:%%M
trayonclose = False
ttl = 1381224
upnp = False
useidenticons = False
userlocale = en
willinglysendtomobile = False

[BM-2cWy7cvHoq3f1rYMerRJp8PT653jjSuEdY]
label = [chan] bitmessage
enabled = true
decoy = false
chan = true
noncetrialsperbyte = 1000
payloadlengthextrabytes = 1000
privsigningkey = 5K42shDERM5g7Kbi3JT5vsAWpXMqRhWZpX835M2pdSoqQQpJMYm
privencryptionkey = 5HwugVWm31gnxtoYcvcK7oywH2ezYTh6Y4tzRxsndAeMi6NHqpA

[BM-2cUzsvYoNbKNNuDnJtdPVS2pbSHzNJyqdD]
label = [chan] find-new-chan
enabled = true
decoy = false
chan = true
noncetrialsperbyte = 1000
payloadlengthextrabytes = 1000
privsigningkey = 5JrsTVeBZYUxYeK5WQgiESBxpfMvqMp2bdvu7FyY356rMqzTdiB
privencryptionkey = 5KXBMwknxy585jkR3TVZuYgBjAawtGfWUp98cmaWvFjAZwC2yaN

[BM-2cW67GEKkHGonXKZLCzouLLxnLym3azS8r]
label = [chan]   general
enabled = true
decoy = false
chan = true
noncetrialsperbyte = 1000
payloadlengthextrabytes = 1000
privsigningkey = 5Jnbdwc4u4DG9ipJxYLznXSvemkRFueQJNHujAQamtDDoX3N1eQ
privencryptionkey = 5JrDcFtQDv5ydcHRW6dfGUEvThoxCCLNEUaxQfy8LXXgTJzVAcq

[BM-2cTaRF4nbj4ByCTH13SUMouK8nHXBLaLmS]
label = NUKED ADDRESS LmS
enabled = true
decoy = false
chan = false
noncetrialsperbyte = 1000
payloadlengthextrabytes = 1000
privsigningkey = 5J9gVWmW9XCjJo1CdymosipSuWRLp2ovaUkJ2JGFc9T1A9SHJvB
privencryptionkey = 5HrrrckD7RPYhiBeRPAqmUUv73ajYnHKgsC2Q2f3AqK9hptr7aN
mailinglist = false
mailinglistname = nuked_PML
lastpubkeysendtime = 1469973237

EOFherefile
) > keys.dat
#-----------------------------------------------------------







#'echo " delete unimportant files                  " ;  rm ./PyBitmessage/* ; cd PyBitmessage ; rm -rf man dev build packages desktop ; cd .. ' \


#   useful in click-launch to add    ; read WAITNOW        #  which will wait for keypress before closing Konsole


# now actually using the menu:

# modify it to your liking        note you are then on  MASTER  branch , not on the newer  ver. 0.6.3   branch

#  run through the options  1 2 3 4   in this order:   1 2 3 4

menu                                                                                                                              \
'echo " clone BitMessage repo below current dir   " ;  git clone -b 'v0.6'  "https://github.com/Bitmessage/PyBitmessage.git"    ' \
'echo " check dependencies i.e. py modules etc.   " ;  cd ./PyBitmessage/ ; python2 checkdeps.py ; cd ..                        ' \
'echo " inject standard KEYS.DAT file             " ;  cp  ./keys.dat                   PyBitmessage/src                        ' \
'echo " run new BM from py source                 " ;  pushd . ; cd  PyBitmessage/src ; ./bitmessagemain.py --curses &     popd ' \
'echo " pull    BM update from github             " ;  pushd . ; cd  PyBitmessage/ ; git pull ;                            popd ' \
'echo " fetch all                                 " ;  pushd . ; cd  PyBitmessage/ ; git fetch --all;                      popd ' \
'echo " git hard reset                            " ;  pushd . ; cd  PyBitmessage/ ; git reset --hard origin/master ;      popd ' \
'echo " kill bitboard, pyBM daemon, plus any py2  " ;  killall python2.7 #bitmessagemain\.                                      ' \
'echo " inst bitboard                             " ;  ibitboard                                                                '
