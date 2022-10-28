using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class CustomLayerEffectFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class CustomEffectsettings{
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
        // public int screenHeight = 144;
        public Material customMaterial;
        public bool IsEnabled = true;
        public LayerMask layerMask = 0;
    }

    RenderTargetHandle renderTargetHandle;
    CustomLayerEffectPass m_CustomPass;

    public CustomEffectsettings settings = new CustomEffectsettings();
    // public FilteringSettings


    public override void Create()
    {
        // FilteringSettings filter = settings.filterSettings;
        m_CustomPass = new CustomLayerEffectPass(
            "snow eff", 
            settings.renderPassEvent, 
            settings.customMaterial,
            settings.layerMask
        );

        // Configures where the render pass should be injected.
        // m_CustomPass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // if(!settings.IsEnabled){
        //     return;
        // }

        var cameraColorTargetIdent = renderer.cameraColorTarget;
        m_CustomPass.Setup(cameraColorTargetIdent);

        renderer.EnqueuePass(m_CustomPass);
    }
}


