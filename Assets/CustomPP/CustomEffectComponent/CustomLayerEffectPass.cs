using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

class CustomLayerEffectPass : ScriptableRenderPass
    {
        string profilerTag;
        Material material;
        RenderTargetIdentifier cameraColorTargetIdent;
        RenderTargetHandle tempTexture;
        FilteringSettings filteringSettings;
        // RenderQueueRange queue = new RenderQueueRange(RenderQueueRange.opaque);

        // private RenderQueue 

        public ShaderTagId ShaderTagId = new ShaderTagId("UniversalForward");

        public CustomLayerEffectPass(string profilerTag, RenderPassEvent renderPassEvent, Material material, int layerMask){
            this.profilerTag = profilerTag;
            this.renderPassEvent = renderPassEvent;
            this.material = material;
            
            filteringSettings = new FilteringSettings(RenderQueueRange.opaque, layerMask);
        }

        public void Setup(RenderTargetIdentifier cameraColorTargetIdent){
            this.cameraColorTargetIdent = cameraColorTargetIdent;
        }

        // This method is called before executing the render pass.
        // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
        // When empty this render pass will render to the active camera render target.
        // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
        // The render pipeline will ensure target setup and clearing happens in an performance manner.
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            cmd.GetTemporaryRT(tempTexture.id, cameraTextureDescriptor);
            ConfigureTarget(tempTexture.id);
            ConfigureClear(ClearFlag.All,Color.red);

            // int tmpp = Shader.PropertyToID
            
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if(renderingData.cameraData.isSceneViewCamera) return;

            // SortingCriteria sortingCriteria = (

            // RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
            // opaqueDesc.depthBufferBits = 0;

            CommandBuffer cmd = CommandBufferPool.Get(profilerTag);

            cmd.Clear();

            context.ExecuteCommandBuffer(cmd);

            var draw1  = CreateDrawingSettings(ShaderTagId,ref renderingData,renderingData.cameraData.defaultOpaqueSortFlags);
            draw1.overrideMaterial = material;
            draw1.overrideMaterialPassIndex = 0;
            context.DrawRenderers(renderingData.cullResults, ref draw1,ref filteringSettings);
            // cmd.SetGlobalTexture("_CameraColorTexture", cameraColorTargetIdent);

            // cmd.Blit(renderingData.cullResults, tempTexture.Identifier(), material, 0);
            // Blit(cmd, tempTexture.Identifier(), cameraColorTargetIdent);
            // cmd.Blit(tempTexture.Identifier(), cameraColorTargetIdent);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        /// Cleanup any allocated resources that were created during the execution of this render pass.
    public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(tempTexture.id);
        }
    }
