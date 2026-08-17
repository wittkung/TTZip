import Foundation
import TTZipCore

@main
struct TTZipCLIMain {
    static func main() async {
        // 初始化底层 C 引擎子系统与信号拦截
        TTZipEngineFacade.initializeSubsystems()
        
        let rawArgs = Array(CommandLine.arguments.dropFirst())
        
        guard !rawArgs.isEmpty else {
            CLICommandRouter.printUsage()
            exit(EXIT_FAILURE)
        }
        
        let command = CLICommand(commandString: rawArgs[0])
        let options = CLIArgumentParser.parse(args: Array(rawArgs.dropFirst()))
        
        await CLICommandRouter.route(command: command, options: options)
    }
}
