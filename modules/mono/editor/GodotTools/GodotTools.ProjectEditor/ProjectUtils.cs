using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.Build.Construction;

namespace GodotTools.ProjectEditor
{
    public sealed class MSBuildProject
    {
        internal ProjectRootElement Root { get; set; }

        public bool HasUnsavedChanges { get; set; }

        public void Save() => Root.Save();

        public MSBuildProject(ProjectRootElement root)
        {
            Root = root;
        }
    }

    public static class ProjectUtils
    {
        private static readonly Dictionary<(string, string), bool> PlatformFrameworks = new()
        {
            {("ios", "net8.0"), false},
            {("android", "net7.0"), false},
        };

        public static void MSBuildLocatorRegisterDefaults(out Version version, out string path)
        {
            var instance = Microsoft.Build.Locator.MSBuildLocator.RegisterDefaults();
            version = instance.Version;
            path = instance.MSBuildPath;
        }

        public static void MSBuildLocatorRegisterMSBuildPath(string msbuildPath)
            => Microsoft.Build.Locator.MSBuildLocator.RegisterMSBuildPath(msbuildPath);

        public static MSBuildProject Open(string path)
        {
            var root = ProjectRootElement.Open(path);
            return root != null ? new MSBuildProject(root) : null;
        }

        public static void MigrateToProjectSdksStyle(MSBuildProject project, string projectName)
        {
            var origRoot = project.Root;

            if (!string.IsNullOrEmpty(origRoot.Sdk))
                return;

            project.Root = ProjectGenerator.GenGameProject(projectName);
            project.Root.FullPath = origRoot.FullPath;
            project.HasUnsavedChanges = true;
        }

        public static void EnsureGodotSdkIsUpToDate(MSBuildProject project)
        {
            var root = project.Root;
            string godotSdkAttrValue = ProjectGenerator.GodotSdkAttrValue;

            if (!string.IsNullOrEmpty(root.Sdk) &&
                root.Sdk.Trim().Equals(godotSdkAttrValue, StringComparison.OrdinalIgnoreCase))
                return;

            root.Sdk = godotSdkAttrValue;
            project.HasUnsavedChanges = true;
        }

        public static void EnsureTargetFrameworkIsSet(MSBuildProject project)
        {
            bool HasNoCondition(ProjectElement element) => string.IsNullOrEmpty(element.Condition);

            bool ConditionMatches(ProjectElement element, string platform) =>
                string.Compare(element.Condition.Trim().Replace(" ", ""),
                    $"'$(GodotTargetPlatform)'=='{platform}'", StringComparison.OrdinalIgnoreCase) == 0;

            // if the existing framework is equal or higher than ours, we're good
            bool IsVersionUsable(string theirs, string ours) =>
                Version.TryParse(theirs.Substring(3), out var versionTheirs) &&
                Version.TryParse(ours.Substring(3), out var versionOurs) &&
                versionTheirs >= versionOurs;

            // if the property already has our condition, we're good
            // if the property has no conditions and the group has no conditions, we can use it
            // if the property has no conditions but the group matches our condition, cool
            bool IsFrameworkUsable(ProjectPropertyGroupElement group, ProjectPropertyElement prop,
                string platform, string framework)
            {
                return IsVersionUsable(prop.Value, framework) &&
                       (ConditionMatches(prop, platform) ||
                        (HasNoCondition(prop) &&
                         (HasNoCondition(group) || ConditionMatches(group, platform))));
            }

            // If the condition matches (in the property or group) but the target framework isn't high enough, replace it
            bool ShouldReplaceProperty(ProjectPropertyGroupElement group, ProjectPropertyElement prop,
                string platform, string framework)
            {
                return !IsVersionUsable(prop.Value, framework) &&
                       (ConditionMatches(prop, platform) ||
                        (HasNoCondition(prop) && ConditionMatches(group, platform)));
            }

            ProjectPropertyGroupElement mainGroup = null;
            Dictionary<ProjectPropertyGroupElement, List<ProjectPropertyElement>> propertiesToRemove = new();

            var root = project.Root;
            bool skipProjectUpdate = false;

            foreach (var group in root.PropertyGroups)
            {
                foreach (var prop in group.Properties)
                {
                    // If the user sets the GodotSkipProjectUpdate property, we don't do anything
                    if (string.Compare(prop.Name, "GodotSkipProjectUpdate", StringComparison.OrdinalIgnoreCase) == 0)
                    {
                        skipProjectUpdate = prop.Value?.ToLower() == "true" || prop.Value == "1";
                    }

                    if (string.Compare(prop.Name, "TargetFramework", StringComparison.OrdinalIgnoreCase) == 0)
                    {
                        // if we need to add the property, we'll add it on the first conditionless property group that
                        // has a TargetFramework, just so everything is close together
                        if (mainGroup == null && HasNoCondition(group))
                            mainGroup = group;

                        foreach (var pf in PlatformFrameworks.Keys)
                        {
                            if (ShouldReplaceProperty(group, prop, pf.Item1, pf.Item2))
                            {
                                if (!propertiesToRemove.ContainsKey(group))
                                    propertiesToRemove.Add(group, new List<ProjectPropertyElement>());

                                propertiesToRemove[group].Add(prop);
                            }
                            PlatformFrameworks[pf] |= IsFrameworkUsable(group, prop, pf.Item1, pf.Item2);
                        }
                    }
                }
            }

            if (skipProjectUpdate)
                return;

            foreach (var toRemove in propertiesToRemove.SelectMany(group => group.Value.Select(prop => (group.Key, prop))))
            {
                toRemove.Key.RemoveChild(toRemove.prop);
            }

            foreach (var pf in PlatformFrameworks)
            {
                if (!pf.Value)
                {
                    // we should have already found the first property group that has a TargetFramework, but if not...
                    mainGroup ??= root.AddPropertyGroup();
                    var prop = mainGroup.AddProperty("TargetFramework", pf.Key.Item2);
                    prop.Condition = $" '$(GodotTargetPlatform)' == '{pf.Key.Item1}' ";
                    project.HasUnsavedChanges = true;
                }
            }
        }
    }
}
