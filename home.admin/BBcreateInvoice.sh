#!/bin/bash
_temp="./download/dialog.$$"
_error="./.error.out"
sudo chmod 7777 ${_error}

# load raspiblitz config data (with backup from old config)
source /home/admin/raspiblitz.info
source /mnt/hdd/raspiblitz.conf
if [ ${#network} -eq 0 ]; then network=`cat .network`; fi
if [ ${#network} -eq 0 ]; then network="bitcoin"; fi
if [ ${#chain} -eq 0 ]; then
  echo "gathering chain info ... please wait"
  chain=$(${network}-cli getblockchaininfo | jq -r '.chain')
fi

# Check if ready (chain in sync and channels open)
./XXchainInSync.sh $network $chain
if [ $? != 0 ]; then
  exit 1
fi

# let user enter the invoice
l1="Enter the AMOUNT IN SATOSHI of the invoice:"
l2="1 ${network} = 100 000 000 SAT"
dialog --title "Pay thru Lightning Network" \
--inputbox "$l1\n$l2" 9 50 2>$_temp
amount=$(cat $_temp | xargs | tr -dc '0-9')
shred $_temp
if [ ${#amount} -eq 0 ]; then
  echo "FAIL - not a valid input (${amount})"
  exit 1
fi

# TODO let user enter a description

# build command
command="lncli --chain=${network} --network=${chain}net addinvoice ${amount}"

# info output
clear
echo "******************************"
echo "Create Invoice / Payment Request"
echo "******************************"
echo ""
echo "COMMAND LINE: "
echo $command
echo ""
echo "RESULT:"
sleep 2

# execute command
result=$($command 2>$_error)
error=`cat ${_error}`

#echo "result(${result})"
#echo "error(${error})"

if [ ${#error} -gt 0 ]; then
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "FAIL"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "${error}"
else
#  echo "******************************"
#  echo "WIN"
#  echo "******************************"
#  echo "${result}"


  rhash=$(echo "$result" | grep r_hash | cut -d '"' -f4)
  payReq=$(echo "$result" | grep pay_req | cut -d '"' -f4)
  echo -e "${payReq}" > qr.txt
  ./XXdisplayQRlcd.sh

  echo
  echo "********************"
  echo "Here is your invoice"
  echo "********************"
  echo
  echo "Give this Invoice/PaymentRequest to someone to pay it:"
  echo
  echo "${payReq}"
  echo
  echo "Do you want to see the invoice QR-code in this terminal? (Y/N)"

  read -n1 key
  if [ "$key" = "y" ]; then
     /home/admin/XXdisplayQR.sh
  fi

  shred qr.txt
  rm -f qr.txt

  clear
  echo "************"
  echo "What's next?"
  echo "************"
  echo
  echo "You can use"
  echo 
  echo "lncli --chain=${network} --network=${chain}net lookupinvoice ${rhash}"
  echo
  echo "to check the payment."

  /home/admin/XXdisplayQRlcd_hide.sh
  # TODO: Offer to go into monitor for incommin payment loop.
  #       Or simply start the loop and show success status when payment occured
fi
