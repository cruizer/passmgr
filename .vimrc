" If this is an add op and there is a file already (flag=1) we concatenate the data already in the file and the current entry.
command -bar WriteEncrypted execute 'w !' . PassMgrScriptLocation '--saveEnc' PassMgrSaveMode
command SavePass WriteEncrypted|q!