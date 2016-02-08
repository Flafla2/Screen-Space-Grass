using UnityEngine;
using System.Collections.Generic;
using UnityEngine.Rendering;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class GrassManager : MonoBehaviour {

    public MeshRenderer[] GrassMeshes;

    public Shader DepthShader;
    public Shader PostProcessShader;
    private Material DepthMaterial;
    private Material PostProcessMaterial;

    // We'll want to add a command buffer on any camera that renders us,
    // so have a dictionary of them.
    private Dictionary<Camera, CommandBuffer> m_Cameras = new Dictionary<Camera, CommandBuffer>();

    // Remove command buffers from all cameras we added into
    private void Cleanup()
    {
        foreach (var cam in m_Cameras)
        {
            if (cam.Key)
            {
                cam.Key.RemoveCommandBuffer(CameraEvent.AfterSkybox, cam.Value);
            }
        }
        m_Cameras.Clear();
        Object.DestroyImmediate(DepthMaterial);
        Object.DestroyImmediate(PostProcessMaterial);
    }

    public void OnEnable()
    {
        Cleanup();
    }

    public void OnDisable()
    {
        Cleanup();
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (!PostProcessMaterial)
        {
            PostProcessMaterial = new Material(PostProcessShader);
            PostProcessMaterial.hideFlags = HideFlags.HideAndDontSave;
        }

        Vector3 up = transform.up;
        PostProcessMaterial.SetVector("up_vec", new Vector2(up.x, up.y).normalized);
        Graphics.Blit(source, destination, PostProcessMaterial);
    }

    public void OnPreRender()
    {
        var act = gameObject.activeInHierarchy && enabled;
        if (!act)
        {
            Cleanup();
            return;
        }

        var cam = Camera.current;
        if (!cam)
            return;

        CommandBuffer buf = null;
        // Did we already add the command buffer on this camera? Nothing to do then.
        if (m_Cameras.ContainsKey(cam))
            return;

        if (!DepthMaterial)
        {
            DepthMaterial = new Material(DepthShader);
            DepthMaterial.hideFlags = HideFlags.HideAndDontSave;
        }

        buf = new CommandBuffer();
        buf.name = "Render Grass Depth Reference";
        m_Cameras[cam] = buf;

        int referenceDepthID = Shader.PropertyToID("_rdepth");
        buf.GetTemporaryRT(referenceDepthID, -1, -1, 24, FilterMode.Point, RenderTextureFormat.Depth);
        buf.SetRenderTarget(new RenderTargetIdentifier(referenceDepthID));
        buf.ClearRenderTarget(true, false, Color.white, 1);

        foreach (MeshRenderer r in GrassMeshes)
            buf.DrawRenderer(r, DepthMaterial);

        buf.SetRenderTarget(new RenderTargetIdentifier(BuiltinRenderTextureType.CameraTarget));

        buf.SetGlobalTexture("_ReferenceDepth", referenceDepthID);

        cam.AddCommandBuffer(CameraEvent.BeforeImageEffects, buf);
        Debug.Log("Add Command Buffer");
    }
}
