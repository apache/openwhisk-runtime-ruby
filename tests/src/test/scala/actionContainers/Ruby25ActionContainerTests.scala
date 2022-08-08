/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package runtime.actionContainers

import org.junit.runner.RunWith
import org.scalatest.junit.JUnitRunner
import common.WskActorSystem
import actionContainers.{ActionContainer, BasicActionRunnerTests}
import actionContainers.ActionContainer.withContainer
import actionContainers.ResourceHelpers.ZipBuilder
import actionContainers.ResourceHelpers
import java.nio.file.FileSystems;
import spray.json._

@RunWith(classOf[JUnitRunner])
class Ruby25ActionContainerTests extends BasicActionRunnerTests with WskActorSystem {
  // note: "out" will not be empty as the Webrick outputs a message during the boot and after the boot
  val enforceEmptyOutputStream = false

  lazy val ruby25ContainerImageName = "action-ruby-v2.5"

  override def withActionContainer(env: Map[String, String] = Map.empty)(code: ActionContainer => Unit) = {
    withContainer(ruby25ContainerImageName, env)(code)
  }

  def withRuby25Container(code: ActionContainer => Unit) = withActionContainer()(code)

  behavior of ruby25ContainerImageName

  override val testNoSourceOrExec = TestConfig("")

  override val testEcho = {
    TestConfig("""
                 |def main(args)
                 |  puts 'hello stdout'
                 |  warn 'hello stderr'
                 |  args
                 |end
               """.stripMargin)
  }

  override val testNotReturningJson = {
    TestConfig(
      """
       |def main(args)
       |  "not a json object"
       |end
     """.stripMargin,
      enforceEmptyOutputStream = enforceEmptyOutputStream,
      enforceEmptyErrorStream = false)
  }

  override val testInitCannotBeCalledMoreThanOnce = {
    TestConfig(
      """
        |def main(args)
        |  args
        |end
      """.stripMargin,
      enforceEmptyOutputStream = enforceEmptyOutputStream)
  }

  override val testEntryPointOtherThanMain = {
    TestConfig(
      """
        |def niam(args)
        |  args
        |end
      """.stripMargin,
      main = "niam",
      enforceEmptyOutputStream = enforceEmptyOutputStream)
  }

  override val testUnicode = {
    TestConfig("""
         |def main(args)
         |  str = args['delimiter'] + " ☃ " + args['delimiter']
         |  print str + "\n"
         |  {"winter" => str}
         |end
         """.stripMargin.trim)
  }

  override val testEnv = {
    TestConfig(
      """
        |def main(args)
        |  {
        |       "env" => ENV,
        |       "api_host" => ENV['__OW_API_HOST'],
        |       "api_key" => ENV['__OW_API_KEY'],
        |       "namespace" => ENV['__OW_NAMESPACE'],
        |       "action_name" => ENV['__OW_ACTION_NAME'],
        |       "action_version" => ENV['__OW_ACTION_VERSION'],
        |       "activation_id" => ENV['__OW_ACTIVATION_ID'],
        |       "deadline" => ENV['__OW_DEADLINE']
        |  }
        |end
      """.stripMargin.trim,
      enforceEmptyOutputStream = enforceEmptyOutputStream)
  }

  override val testLargeInput = {
    TestConfig("""
        |def main(args)
        |  args
        |end
      """.stripMargin)
  }

  it should "fail to initialize with bad code" in {
    val (out, err) = withRuby25Container { c =>
      val code = """
                | 10 PRINT "Hello world!"
                | 20 GOTO 10
            """.stripMargin

      val (initCode, error) = c.init(initPayload(code))
      initCode should not be (200)
      error shouldBe a[Some[_]]
      error.get shouldBe a[JsObject]
      error.get.fields("error").toString should include("failed to parse the input code")
    }

    // Somewhere, the logs should mention an error occurred.
    checkStreams(out, err, {
      case (o, e) =>
        (o + e).toLowerCase should include("invalid")
        (o + e).toLowerCase should include("parse")
    })
  }

  it should "return some error on action error" in {
    val (out, err) = withRuby25Container { c =>
      val code = """
                | def main(args)
                |   raise Exception.new("nooooo")
                | end
            """.stripMargin

      val (initCode, _) = c.init(initPayload(code))
      initCode should be(200)

      val (runCode, runRes) = c.run(runPayload(JsObject()))
      runCode should not be (200)

      runRes shouldBe defined
      runRes.get.fields.get("error") shouldBe defined
    // runRes.get.fields("error").toString.toLowerCase should include("nooooo")
    }

    // Somewhere, the logs should be the error text
    checkStreams(out, err, {
      case (o, e) =>
        (o + e).toLowerCase should include("nooooo")
    })

  }

  it should "support application errors" in {
    withRuby25Container { c =>
      val code = """
                | def main(args)
                |   { "error" => "sorry" }
                | end
            """.stripMargin;

      val (initCode, error) = c.init(initPayload(code))
      initCode should be(200)

      val (runCode, runRes) = c.run(runPayload(JsObject()))
      runCode should be(200) // action writer returning an error is OK

      runRes shouldBe defined
      runRes.get.fields.get("error") shouldBe defined
      runRes.get.fields("error").toString.toLowerCase should include("sorry")
    }
  }

  it should "fail gracefully when an action has a TypeError exception" in {
    val (out, err) = withRuby25Container { c =>
      val code = """
                | def main(args)
                |   eval "class ENV\nend"
                |   { "hello" => "world" }
                | end
            """.stripMargin;

      val (initCode, _) = c.init(initPayload(code))
      initCode should be(200)

      val (runCode, runRes) = c.run(runPayload(JsObject()))
      runCode should be(502)

      runRes shouldBe defined
      runRes.get.fields.get("error") shouldBe defined
      runRes.get.fields("error").toString should include("An error occurred running the action")
    }

    // Somewhere, the logs should be the error text
    checkStreams(out, err, {
      case (o, e) =>
        (o + e).toLowerCase should include("typeerror")
    })
  }

  it should "support the documentation examples (1)" in {
    val (out, err) = withRuby25Container { c =>
      val code = """
                | def main(params)
                |   if (params['payload'] == 0) then
                |     return {}
                |   elsif params['payload'] == 1 then
                |     return {'payload' => 'Hello, World!'} # indicates normal completion
                |   elsif params['payload'] == 2 then
                |     return {'error' => 'payload must be 0 or 1'}  # indicates abnormal completion
                |   end
                | end
            """.stripMargin

      c.init(initPayload(code))._1 should be(200)

      val (c1, r1) = c.run(runPayload(JsObject("payload" -> JsNumber(0))))
      val (c2, r2) = c.run(runPayload(JsObject("payload" -> JsNumber(1))))
      val (c3, r3) = c.run(runPayload(JsObject("payload" -> JsNumber(2))))

      c1 should be(200)
      r1 should be(Some(JsObject()))

      c2 should be(200)
      r2 should be(Some(JsObject("payload" -> JsString("Hello, World!"))))

      c3 should be(200) // application error, not container or system
      r3.get.fields.get("error") shouldBe Some(JsString("payload must be 0 or 1"))
    }
  }

  it should "have mechanize and activesupport gems available" in {
    // GIVEN that it should "error when requiring a non-existent package" (see test above for this)
    val (out, err) = withRuby25Container { c =>
      val code = """
                | require 'mechanize'
                | require 'active_support'
                | def main(args)
                |   Mechanize.class
                |   ActiveSupport.class
                |   {}
                | end
            """.stripMargin

      val (initCode, _) = c.init(initPayload(code))

      initCode should be(200)

      // WHEN I run an action that calls a Guzzle & a Uuid method
      val (runCode, out) = c.run(runPayload(JsObject()))

      // THEN it should pass only when these packages are available
      runCode should be(200)
    }
  }

  it should "support large-ish actions" in {
    val thought = " I took the one less traveled by, and that has made all the difference."
    val assignment = "    x = \"" + thought + "\";\n"

    val code = """
            | def main(args)
            |   x = "hello"
            """.stripMargin + (assignment * 7000) + """
            |   x = "world"
            |   { "message" => x }
            | end
            """.stripMargin

    // Lest someone should make it too easy.
    code.length should be >= 500000

    val (out, err) = withRuby25Container { c =>
      c.init(initPayload(code))._1 should be(200)

      val (runCode, runRes) = c.run(runPayload(JsObject()))

      runCode should be(200)
      runRes.get.fields.get("message") shouldBe defined
      runRes.get.fields.get("message") shouldBe Some(JsString("world"))
    }
  }

  val exampleOutputDotRuby: String = """
        | def output(data)
        |   {'result' => data}
        | end
    """.stripMargin

  it should "support zip-encoded packages" in {
    val srcs = Seq(
      Seq("output.rb") -> exampleOutputDotRuby,
      Seq("main.rb") -> """
                | require __dir__ + '/output.rb'
                | def main(args)
                |   name = args['name'] || 'stranger'
                |   output(name)
                | end
            """.stripMargin)

    val code = ZipBuilder.mkBase64Zip(srcs)

    val (out, err) = withRuby25Container { c =>
      c.init(initPayload(code))._1 should be(200)

      val (runCode, runRes) = c.run(runPayload(JsObject()))

      runCode should be(200)
      runRes.get.fields.get("result") shouldBe defined
      runRes.get.fields.get("result") shouldBe Some(JsString("stranger"))
    }
  }

  it should "support zip-encoded packages without directory entries" in {
    val path = FileSystems.getDefault().getPath("src", "test", "resources", "without_dir_entries.zip");
    val code = ResourceHelpers.readAsBase64(path)

    val (out, err) = withRuby25Container { c =>
      c.init(initPayload(code))._1 should be(200)

      val (runCode, runRes) = c.run(runPayload(JsObject()))

      runCode should be(200)
      runRes.get.fields.get("greeting") shouldBe defined
      runRes.get.fields.get("greeting") shouldBe Some(JsString("Hello stranger!"))
    }
  }

  it should "fail gracefully on invalid zip files" in {
    // Some text-file encoded to base64.
    val code = "Q2VjaSBuJ2VzdCBwYXMgdW4gemlwLgo="

    val (out, err) = withRuby25Container { c =>
      val (initCode, error) = c.init(initPayload(code))
      initCode should not be (200)
      error shouldBe a[Some[_]]
      error.get shouldBe a[JsObject]
      error.get.fields("error").toString should include("failed to open zip file")
    }

    // Somewhere, the logs should mention the failure
    checkStreams(out, err, {
      case (o, e) =>
        (o + e).toLowerCase should include("error")
        (o + e).toLowerCase should include("failed to open zip file")
    })
  }

  it should "fail gracefully on valid zip files that are not actions" in {
    val srcs = Seq(Seq("hello") -> """
                | Hello world!
            """.stripMargin)

    val code = ZipBuilder.mkBase64Zip(srcs)

    val (out, err) = withRuby25Container { c =>
      c.init(initPayload(code))._1 should not be (200)
    }

    checkStreams(out, err, {
      case (o, e) =>
        (o + e).toLowerCase should include("error")
        (o + e).toLowerCase should include("zipped actions must contain main.rb at the root.")
    })
  }

  it should "fail gracefully on valid zip files with invalid code in main.rb" in {
    val (out, err) = withRuby25Container { c =>
      val srcs = Seq(Seq("main.rb") -> """
                    | 10 PRINT "Hello world!"
                    | 20 GOTO 10
                """.stripMargin)

      val code = ZipBuilder.mkBase64Zip(srcs)

      val (initCode, error) = c.init(initPayload(code))
      initCode should not be (200)
      error shouldBe a[Some[_]]
      error.get shouldBe a[JsObject]
      error.get.fields("error").toString should include("failed to parse the input code")
    }

    // Somewhere, the logs should mention an error occurred.
    checkStreams(out, err, {
      case (o, e) =>
        (o + e).toLowerCase should include("invalid")
        (o + e).toLowerCase should include("parse")
    })
  }

  it should "support zipped actions using non-default entry point" in {
    val srcs = Seq(Seq("main.rb") -> """
                | def niam(args)
                |   { :result => "it works" }
                | end
            """.stripMargin)

    val code = ZipBuilder.mkBase64Zip(srcs)

    withRuby25Container { c =>
      c.init(initPayload(code, main = "niam"))._1 should be(200)

      val (runCode, runRes) = c.run(runPayload(JsObject()))
      runRes.get.fields.get("result") shouldBe Some(JsString("it works"))
    }
  }

  it should "support return array result" in {
    val (out, err) = withRuby25Container { c =>
      val code = """
                   | def main(args)
                   |   nums = Array["a","b"]
                   |   nums
                   | end
                 """.stripMargin

      val (initCode, _) = c.init(initPayload(code))

      initCode should be(200)

      val (runCode, runRes) = c.runForJsArray(runPayload(JsObject()))
      runCode should be(200)
      runRes shouldBe Some(JsArray(JsString("a"), JsString("b")))
    }
  }

  it should "support array as input param" in {
    val (out, err) = withRuby25Container { c =>
      val code = """
                   | def main(args)
                   |   args
                   | end
                 """.stripMargin

      val (initCode, _) = c.init(initPayload(code))

      initCode should be(200)

      val (runCode, runRes) = c.runForJsArray(runPayload(JsArray(JsString("a"), JsString("b"))))
      runCode should be(200)
      runRes shouldBe Some(JsArray(JsString("a"), JsString("b")))
    }
  }
}
