import { ConfigMap } from "@pulumi/pulumi/automation";
import { PulumiBoxManager } from "../pulumi.js";
import { ec2InstanceProgram } from "../../lib/infra/pulumi/programs/ec2-instance.js";
import { CompositeEC2InstanceArgs } from "../../lib/infra/pulumi/components/aws/ec2.js";
import { CloudVMBoxManager, outputsFromPulumi } from "../common/cloud-virtual-machine.js";

export interface EC2InstanceBoxArgs {
    aws?: {
        region?: string
    }
    infraArgs: CompositeEC2InstanceArgs
}

export class EC2InstanceBoxManager implements CloudVMBoxManager {
    
    readonly args: EC2InstanceBoxArgs
    readonly name: string
    readonly pulumiBm: PulumiBoxManager

    constructor(name: string, args: EC2InstanceBoxArgs){
        this.name = name
        this.args = args
        this.pulumiBm = buildPulumiBoxManager(name, args)
    }

    async deploy() {
        const o = await this.pulumiBm.deploy()
        return outputsFromPulumi(o)        
    }
    
    async destroy() {
        return this.pulumiBm.destroy()
    }

    async preview() {
        return this.pulumiBm.preview()    
    }

    async provision() {
        return this.get()
    }

    async get() {
        const o = await this.pulumiBm.get()
        return outputsFromPulumi(o)    
    }

    // async reboot(){
    //     const bm = await this.getNixosBoxManager()
    //     await bm.runSshCommand(["reboot"])
    // }
}

function buildPulumiBoxManager(name: string, args: EC2InstanceBoxArgs) : PulumiBoxManager {

    // TODO generic for AWS stacks ?
    const pulumiConfig : ConfigMap = {}
    if(args.aws?.region) {
        pulumiConfig["aws:region"] = { value: args.aws?.region }
    }

    return new PulumiBoxManager({
        stackName: name,
        projectName: `cloudybox-ec2-instance`,
        program: async () => {
            return ec2InstanceProgram(name, args.infraArgs)
        },
        config: pulumiConfig
    })
}