import com.cloudbees.hudson.plugins.folder.properties.FolderCredentialsProvider
import com.cloudbees.plugins.credentials.common.StandardCredentials
import com.cloudbees.hudson.plugins.folder.Folder

// for global creds only
def creds = com.cloudbees.plugins.credentials.CredentialsProvider.lookupCredentials(
com.cloudbees.plugins.credentials.common.StandardCredentials.class,
    Jenkins.instance,
    null,
    null
);
for (int i; i < creds.size(); i++) {
  println "\n========== Credential ${i+1} Start =========="
  creds[i].properties.each { println it }
  println "========== Credential ${i+1} End   ==========\n"
}

// for folder creds
def folders = Jenkins.getInstance().getItems(Folder);
def folderCredsMap = folders.collect {
  folder ->def folderName = folder.name
  def folderDomainCredentials = folder.properties.get(FolderCredentialsProvider.FolderCredentialsProperty.class).domainCredentials
  def folderCredentials = []
  folderDomainCredentials.each {
    def credentials = it.credentials;
    credentials.each {
      folderCredentials << it
    }
  }
  return [folderName: folderName, credentials: folderCredentials]
}
folderCredsMap.each {
  def folderName = it.folderName
  it.credentials.eachWithIndex {
    folderCred,
    i ->println "\n========== [${folderName}] Credential ${i+1} Start =========="
    folderCred.properties.each {
      println it
    }
    println "========== [${folderName}] Credential ${i+1} End   ==========\n"
  }
}
return
