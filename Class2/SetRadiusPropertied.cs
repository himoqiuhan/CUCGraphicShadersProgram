using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class SetRadiusPropertied : MonoBehaviour
{
    public Material radiusMaterial;

    [Range(0.5f, 50.0f)]public float radius = 1;
    [Range(0.01f, 1.0f)]public float radiusWidth = 0.5f;

    public Color color = Color.white;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (radiusMaterial != null)
        {
            radiusMaterial.SetVector("_Center", transform.position);
            radiusMaterial.SetFloat("_Radius", radius);
            radiusMaterial.SetColor("_RadiusColor", color);
            radiusMaterial.SetFloat("_RaduisWidth", radiusWidth);
        }
    }
}
