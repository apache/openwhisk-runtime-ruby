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

import actionContainers.ActionContainer.withContainer
import actionContainers.{ActionContainer, BasicActionRunnerTests}
import common.WskActorSystem
import org.junit.runner.RunWith
import org.scalatest.junit.JUnitRunner

@RunWith(classOf[JUnitRunner])
class Ruby26ActionLoopContainerTests extends BasicActionRunnerTests with WskActorSystem {

  val image = "actionloop-ruby-v2.6"

  override def withActionContainer(env: Map[String, String] = Map.empty)(
    code: ActionContainer => Unit) = {
    withContainer(image, env)(code)
  }

  def withActionLoopContainer(code: ActionContainer => Unit) =
    withContainer(image)(code)

  behavior of image

  override val testNoSourceOrExec = TestConfig("")

  override val testNotReturningJson =
    TestConfig(
      """|def main(args)
         |  "not a json object"
         |end
         |""".stripMargin)

  override val testEcho = TestConfig(
    """|def main(args)
       |  puts 'hello stdout'
       |  warn 'hello stderr'
       |  args
       |end
       |""".stripMargin)

  override val testUnicode = TestConfig(
    """|def main(args)
       |  str = args['delimiter'] + " ☃ " + args['delimiter']
       |  print str + "\n"
       |  {"winter" => str}
       |end
       |""".stripMargin)

  override val testEnv = TestConfig(
    """|def main(args)
       |  {
       |       "api_host" => ENV['__OW_API_HOST'],
       |       "api_key" => ENV['__OW_API_KEY'],
       |       "namespace" => ENV['__OW_NAMESPACE'],
       |       "action_name" => ENV['__OW_ACTION_NAME'],
       |       "activation_id" => ENV['__OW_ACTIVATION_ID'],
       |       "deadline" => ENV['__OW_DEADLINE']
       |  }
       |end
       |""".stripMargin, enforceEmptyOutputStream=false)

  override val testInitCannotBeCalledMoreThanOnce = TestConfig(
    s"""|def main(args)
        |  args
        |end
        |""".stripMargin)

  override val testEntryPointOtherThanMain = TestConfig(
    s"""|def niam(args)
        |  args
        |end
        |""".stripMargin, main = "niam")

  override val testLargeInput = TestConfig(
    s"""|def main(args)
        |  args
        |end
        |""".stripMargin)
}
