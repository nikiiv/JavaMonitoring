defmodule JavaMonitorTest do
  use ExUnit.Case
  alias JavaMonitor
  alias JavaMonitor.Parser

  @jinfo_output  """
      Java System Properties:
      #Fri Feb 28 06:20:11 EST 2025
      java.specification.version=17
      sun.jnu.encoding=UTF-8
      java.class.path=./..//build/classes\:/worker/classes\:./..//patches\:./..//lib/activation-1.1.jar\:./..//lib/aggs-matrix-stats-client-7.17.0.jar\:./..//lib/agrona-1.9.0.jar\:./..//lib/akka-actor_2.13-2.6.14.jar\:./..//lib/akka-actor-typed_2.13-2.6.14.jar\:./..//lib/akka-cluster_2.13-2.6.14.jar\:./..//lib/akka-cluster-sharding_2.13-2.6.14.jar\:./..//lib/akka-cluster-sharding-typed_2.13-2.6.14.jar\:./..//lib/akka-cluster-tools_2.13-2.6.14.jar\:./..//lib/akka-cluster-typed_2.13-2.6.14.jar\
      java.vm.vendor=Amazon.com Inc.
      sun.arch.data.model=64
      akka.agent.system.base.name=mostagents
      com.netfolio.fullname=mostagents
      java.vendor.url=https\://aws.amazon.com/corretto/
      user.timezone=America/New_York
      os.name=Linux
      java.vm.specification.version=17
      cache.preheat=yes
      sun.java.launcher=SUN_STANDARD
      user.country=US
      sun.boot.library.path=/usr/lib/jvm/java-17-amazon-corretto/lib
      sun.java.command=atomatron.worker.agentsystem.Main
      worker.agent.xmlfile=./..//etc/mostagents.xml
      jdk.debug=release
      sun.cpu.endian=little
      user.home=/home/geowealth
      user.language=en
      worker.reactorpool.size=100
      java.specification.vendor=Oracle Corporation
      akka.config.file=production.conf
      java.version.date=2025-01-21
      net.sf.ehcache.skipUpdateCheck=true
      java.home=/usr/lib/jvm/java-17-amazon-corretto
      file.separator=/
      java.vm.compressedOopsMode=Zero based
      line.separator=\n
      java.vm.specification.vendor=Oracle Corporation
      java.specification.name=Java Platform API Specification
      java.awt.headless=true
      com.netfolio.appname=mostagents
      com.netfolio.fullname=mostagents1
      sun.management.compiler=HotSpot 64-Bit Tiered Compilers
      java.runtime.version=17.0.14+7-LTS
      user.name=geowealth
      openAccountApplicationUploadFiles.location=/efs2/data/openAccountApplicationFiles
      worker.hostport.filename=./..//pids/mostagents.pair
      path.separator=\:
      os.version=5.4.17-2136.339.5.el8uek.x86_64
      java.runtime.name=OpenJDK Runtime Environment
      file.encoding=UTF-8
      java.vm.name=OpenJDK 64-Bit Server VM
      java.vendor.version=Corretto-17.0.14.7.1
      java.vendor.url.bug=https\://github.com/corretto/corretto-17/issues/
      netfolio.home=./../
      java.io.tmpdir=/tmp
      java.version=17.0.14
      user.dir=/geowealth/adviser/akkatron/bin
      os.arch=amd64
      java.vm.specification.name=Java Virtual Machine Specification
      ehcache.distributed.config=ehcacheBeanCacheApp.xml
      mail.mime.multipart.allowempty=true
      native.encoding=UTF-8
      java.library.path=/usr/local/oracle8i/OraHome/lib\:/usr/java/packages/lib\:/usr/lib64\:/lib64\:/lib\:/usr/lib
      oracle.jdbc.DateZeroTime=true
      java.vm.info=mixed mode, sharing
      java.vendor=Amazon.com Inc.
      java.vm.version=17.0.14+7-LTS
      java.specification.maintenance.version=1
      sun.io.unicode.encoding=UnicodeLittle
      java.class.version=61.0
      """

  describe "parse_jinfo_output/1" do
    test "parses jinfo output correctly and extracts app_name" do


      result = Parser.parse_jinfo_output(@jinfo_output)
      assert result["com.netfolio.appname"] == "mostagents"
      assert result["com.netfolio.fullname"] == "mostagents1"

      app_info = Parser.extract_app_info(result)
      assert app_info.app_name == "mostagents"
      assert app_info.variant == "mostagents1"
    end

 end
end
